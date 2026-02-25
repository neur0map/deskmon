import Crypto
import Foundation
import os
import SwiftUI

// Codable snapshot of the fields that need to survive across launches.
private struct ServerConfig: Codable {
    let id: UUID
    let name: String
    let host: String
    let username: String
    let sshPort: Int
    let agentPort: Int
    let hasKeyInstalled: Bool
}

@MainActor
@Observable
final class ServerManager {
    var servers: [ServerInfo] = []
    var selectedServerID: UUID?
    var isConnected = false
    var alertManager: AlertManager?

    private static let log = Logger(subsystem: "prowlsh.deskmon", category: "ServerManager")
    private static let serversKey = "savedServers"
    private static let selectedIDKey = "selectedServerID"
    private let client = AgentClient.shared
    private var sshManagers: [UUID: SSHManager] = [:]
    private var streamTasks: [UUID: Task<Void, Never>] = [:]

    var selectedServer: ServerInfo? {
        servers.first { $0.id == selectedServerID }
    }

    var currentStatus: ServerStatus {
        selectedServer?.status ?? .offline
    }

    /// The tunnel base URL for the selected server (used by views for actions).
    private func baseURL(for server: ServerInfo) -> String? {
        sshManagers[server.id]?.tunnelBaseURL
    }

    // MARK: - Persistence

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.serversKey),
           let configs = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            servers = configs.map {
                ServerInfo(id: $0.id, name: $0.name, host: $0.host, username: $0.username,
                           sshPort: $0.sshPort, agentPort: $0.agentPort, hasKeyInstalled: $0.hasKeyInstalled)
            }
        }
        if let data = UserDefaults.standard.data(forKey: Self.selectedIDKey),
           let id = try? JSONDecoder().decode(UUID.self, from: data),
           servers.contains(where: { $0.id == id }) {
            selectedServerID = id
        } else {
            selectedServerID = servers.first?.id
        }
    }

    private func saveToDisk() {
        let configs = servers.map {
            ServerConfig(id: $0.id, name: $0.name, host: $0.host, username: $0.username,
                         sshPort: $0.sshPort, agentPort: $0.agentPort, hasKeyInstalled: $0.hasKeyInstalled)
        }
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: Self.serversKey)
        }
        if let data = try? JSONEncoder().encode(selectedServerID) {
            UserDefaults.standard.set(data, forKey: Self.selectedIDKey)
        }
    }

    // MARK: - SSH Connection

    /// Connect to a server: SSH → tunnel → verify agent → start SSE.
    /// Called from AddServerSheet on first setup (password auth).
    func connectServer(_ server: ServerInfo, password: String) async throws {
        let ssh = SSHManager()
        sshManagers[server.id] = ssh

        server.connectionPhase = .sshConnecting

        // SSH connect
        try await ssh.connect(
            host: server.host,
            port: server.sshPort,
            username: server.username,
            password: password
        )

        // Open tunnel
        try await ssh.openTunnel(remotePort: server.agentPort)
        server.connectionPhase = .tunnelOpen

        // Verify agent is reachable through tunnel
        guard let url = ssh.tunnelBaseURL else {
            throw SSHTunnelError.notConnected
        }

        let response = try await client.fetchStats(baseURL: url)
        applyFullSnapshot(server: server, response: response)

        // Store password in Keychain
        try? KeychainStore.savePassword(password, for: server.id)

        // Wire disconnect handler
        ssh.onDisconnect { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleSSHDisconnect(serverID: server.id)
            }
        }

        // Start SSE stream
        startStream(for: server)

        // Background: generate and install SSH key
        Task {
            await installSSHKey(for: server, ssh: ssh)
        }
    }

    /// Connect to a server using SSH key file data for authentication.
    /// Called from AddServerSheet when the user selects an SSH key file.
    func connectServer(_ server: ServerInfo, keyData: Data, passphrase: String? = nil) async throws {
        let ssh = SSHManager()
        sshManagers[server.id] = ssh

        server.connectionPhase = .sshConnecting

        // Parse the OpenSSH private key from file data (handles encrypted keys via passphrase)
        let privateKey = try SSHKeyGenerator.parsePrivateKey(from: keyData, passphrase: passphrase)

        // SSH connect with key
        try await ssh.connect(
            host: server.host,
            port: server.sshPort,
            username: server.username,
            privateKey: privateKey
        )

        // Open tunnel
        try await ssh.openTunnel(remotePort: server.agentPort)
        server.connectionPhase = .tunnelOpen

        // Verify agent is reachable through tunnel
        guard let url = ssh.tunnelBaseURL else {
            throw SSHTunnelError.notConnected
        }

        let response = try await client.fetchStats(baseURL: url)
        applyFullSnapshot(server: server, response: response)

        // Wire disconnect handler
        ssh.onDisconnect { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleSSHDisconnect(serverID: server.id)
            }
        }

        // Start SSE stream
        startStream(for: server)

        // Background: generate and install SSH key for future reconnects
        Task {
            await installSSHKey(for: server, ssh: ssh)
        }
    }

    /// Reconnect a saved server using stored credentials (key first, then password fallback).
    func reconnectServer(_ server: ServerInfo) async {
        let ssh = SSHManager()
        sshManagers[server.id] = ssh

        if !server.hasConnectedOnce {
            server.connectionPhase = .sshConnecting
        }

        // Try key auth first
        if server.hasKeyInstalled,
           let keyData = KeychainStore.loadPrivateKey(for: server.id),
           let privateKey = try? SSHKeyGenerator.privateKey(from: keyData) {
            do {
                try await ssh.connect(
                    host: server.host,
                    port: server.sshPort,
                    username: server.username,
                    privateKey: privateKey
                )
            } catch {
                Self.log.info("Key auth failed for \(server.name), trying password")
            }
        }

        // Fall back to password
        if !ssh.isConnected {
            guard let password = KeychainStore.loadPassword(for: server.id) else {
                Self.log.error("No stored credentials for \(server.name)")
                withAnimation { server.status = .unauthorized }
                server.connectionPhase = .disconnected
                return
            }

            do {
                try await ssh.connect(
                    host: server.host,
                    port: server.sshPort,
                    username: server.username,
                    password: password
                )
            } catch {
                Self.log.error("Password auth failed for \(server.name): \(error.localizedDescription)")
                withAnimation { server.status = .unauthorized }
                server.connectionPhase = .disconnected
                return
            }
        }

        // Open tunnel
        do {
            try await ssh.openTunnel(remotePort: server.agentPort)
            server.connectionPhase = .tunnelOpen
        } catch {
            Self.log.error("Tunnel failed for \(server.name): \(error.localizedDescription)")
            withAnimation { server.status = .offline }
            server.connectionPhase = .disconnected
            return
        }

        // Wire disconnect handler
        ssh.onDisconnect { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleSSHDisconnect(serverID: server.id)
            }
        }

        // Start stream loop (fetches snapshot + SSE)
        startStream(for: server)
    }

    // MARK: - SSE Streaming

    /// Starts an SSE stream for every server that doesn't already have one.
    func startStreaming() {
        for server in servers {
            guard streamTasks[server.id] == nil else { continue }
            Task { await reconnectServer(server) }
        }
    }

    /// Stops all SSE streams and SSH connections.
    func stopStreaming() {
        for (_, task) in streamTasks {
            task.cancel()
        }
        streamTasks.removeAll()
        for (_, ssh) in sshManagers {
            ssh.disconnect()
        }
        sshManagers.removeAll()
        isConnected = false
    }

    /// Starts (or restarts) the SSE stream for a single server.
    /// Assumes SSH tunnel is already open.
    private func startStream(for server: ServerInfo) {
        streamTasks[server.id]?.cancel()

        streamTasks[server.id] = Task {
            let serverID = server.id
            var backoff: UInt64 = 2

            while !Task.isCancelled {
                guard let url = baseURL(for: server) else {
                    // Tunnel not open yet — wait and retry
                    try? await Task.sleep(for: .seconds(backoff))
                    backoff = min(backoff * 2, 30)
                    continue
                }

                var goLiveTimer: Task<Void, Never>?

                // Step 1: Fetch full snapshot
                do {
                    let response = try await client.fetchStats(baseURL: url)
                    applyFullSnapshot(server: server, response: response)
                } catch {
                    Self.log.error("Fetch failed for \(server.name): \(error.localizedDescription)")
                    withAnimation { server.status = .offline }
                    if serverID == selectedServerID { isConnected = false }
                    try? await Task.sleep(for: .seconds(backoff))
                    backoff = min(backoff * 2, 30)
                    continue
                }

                // Start go-live countdown for first connection
                if !server.hasConnectedOnce && server.connectionPhase == .syncing {
                    goLiveTimer = Task {
                        try? await Task.sleep(for: .seconds(3))
                        guard !Task.isCancelled else { return }
                        withAnimation(.smooth(duration: 0.5)) {
                            server.connectionPhase = .live
                            server.hasConnectedOnce = true
                        }
                    }
                }

                // Step 2: Open SSE stream with periodic fallback refresh
                let stream = client.streamStats(baseURL: url)

                // Fallback: poll every 30s in case SSE silently stalls
                let pollTask = Task {
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(30))
                        guard !Task.isCancelled else { break }
                        guard let pollURL = baseURL(for: server) else { break }
                        if let response = try? await client.fetchStats(baseURL: pollURL) {
                            applyFullSnapshot(server: server, response: response)
                        }
                    }
                }

                var receivedSSEEvent = false
                do {
                    for try await event in stream {
                        guard !Task.isCancelled else { break }

                        receivedSSEEvent = true
                        backoff = 2

                        switch event {
                        case .system(let stats, let processes):
                            withAnimation(.easeInOut(duration: 0.4)) {
                                server.stats = stats
                                server.processes = processes
                                server.status = Self.deriveStatus(from: stats)
                            }
                            server.appendNetworkSample(stats.network)
                            if serverID == selectedServerID {
                                isConnected = true
                            }
                            alertManager?.evaluateSystem(
                                serverID: serverID,
                                serverName: server.name,
                                stats: stats
                            )

                        case .docker(let containers):
                            withAnimation(.easeInOut(duration: 0.5)) {
                                server.containers = containers
                            }
                            alertManager?.evaluateContainers(
                                serverID: serverID,
                                serverName: server.name,
                                containers: containers
                            )

                        case .keepalive:
                            break
                        }
                    }
                } catch {
                    Self.log.error("SSE stream error for \(server.name): \(error.localizedDescription)")
                }

                pollTask.cancel()
                goLiveTimer?.cancel()

                guard !Task.isCancelled else { break }

                if !receivedSSEEvent {
                    Self.log.warning("SSE stream for \(server.name) closed without delivering any events")
                }

                withAnimation { server.status = .offline }
                if serverID == selectedServerID {
                    isConnected = false
                }

                try? await Task.sleep(for: .seconds(backoff))
                backoff = min(backoff * 2, 30)
            }
        }
    }

    /// Applies a full GET /stats response to the server.
    private func applyFullSnapshot(server: ServerInfo, response: AgentStatsResponse) {
        withAnimation(.easeInOut(duration: 0.5)) {
            server.stats = response.system
            server.containers = response.containers
            server.processes = response.processes ?? []
            server.appendNetworkSample(response.system.network)
            server.status = Self.deriveStatus(from: response.system)
        }

        // Phase transition after snapshot
        if !server.hasConnectedOnce && server.connectionPhase == .tunnelOpen {
            withAnimation(.smooth(duration: 0.3)) {
                server.connectionPhase = .syncing
            }
        } else if server.hasConnectedOnce && server.connectionPhase != .live {
            server.connectionPhase = .live
        }

        if server.id == selectedServerID {
            isConnected = true
        }
    }

    // MARK: - SSH Disconnect Handling

    private func handleSSHDisconnect(serverID: UUID) {
        guard let server = servers.first(where: { $0.id == serverID }) else { return }

        Self.log.warning("SSH disconnected for \(server.name), starting reconnect")

        streamTasks[serverID]?.cancel()
        streamTasks.removeValue(forKey: serverID)
        sshManagers.removeValue(forKey: serverID)

        withAnimation {
            server.status = .offline
            server.connectionPhase = .disconnected
        }
        if serverID == selectedServerID {
            isConnected = false
        }

        // Auto-reconnect with backoff
        Task {
            var backoff: UInt64 = 2
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(backoff))

                guard servers.contains(where: { $0.id == serverID }) else { return }

                await reconnectServer(server)
                if sshManagers[serverID]?.isConnected == true {
                    return // Reconnected successfully
                }

                backoff = min(backoff * 2, 30)
            }
        }
    }

    // MARK: - SSH Key Installation (Background)

    private func installSSHKey(for server: ServerInfo, ssh: SSHManager) async {
        guard !server.hasKeyInstalled else { return }

        let keyPair = SSHKeyGenerator.generateKeyPair()

        do {
            try await SSHKeyGenerator.installPublicKey(on: ssh, authorizedKeysLine: keyPair.authorizedKeysLine)
            try KeychainStore.savePrivateKey(keyPair.privateKeyData, for: server.id)
            server.hasKeyInstalled = true
            saveToDisk()
            Self.log.info("SSH key installed for \(server.name)")
        } catch {
            Self.log.error("SSH key install failed for \(server.name): \(error.localizedDescription)")
        }
    }

    // MARK: - Server Management

    func addServer(name: String, host: String, username: String, sshPort: Int = 22, agentPort: Int = 7654) -> ServerInfo {
        let server = ServerInfo(name: name, host: host, username: username, sshPort: sshPort, agentPort: agentPort)
        servers.append(server)
        if selectedServerID == nil {
            selectedServerID = server.id
        }
        saveToDisk()
        return server
    }

    func updateServer(id: UUID, name: String, host: String, username: String, sshPort: Int = 22) {
        guard let server = servers.first(where: { $0.id == id }) else { return }
        let connectionChanged = host != server.host || username != server.username || sshPort != server.sshPort
        server.name = name
        server.host = host
        server.username = username
        server.sshPort = sshPort
        saveToDisk()

        if connectionChanged {
            // Disconnect and reconnect with new settings
            streamTasks[id]?.cancel()
            streamTasks.removeValue(forKey: id)
            sshManagers[id]?.disconnect()
            sshManagers.removeValue(forKey: id)
            server.hasKeyInstalled = false
            Task { await reconnectServer(server) }
        }
    }

    func deleteServer(_ server: ServerInfo) {
        streamTasks[server.id]?.cancel()
        streamTasks.removeValue(forKey: server.id)
        sshManagers[server.id]?.disconnect()
        sshManagers.removeValue(forKey: server.id)
        KeychainStore.deleteAll(for: server.id)
        alertManager?.removeConfig(for: server.id)
        servers.removeAll { $0.id == server.id }
        if selectedServerID == server.id {
            selectedServerID = servers.first?.id
        }
        saveToDisk()
    }

    func selectServer(_ server: ServerInfo) {
        selectedServerID = server.id
        isConnected = server.status != .offline && server.status != .unauthorized
        saveToDisk()
    }

    // MARK: - Server Actions

    func performContainerAction(containerID: String, action: ContainerAction) async throws -> String {
        guard let server = selectedServer,
              let url = baseURL(for: server) else { throw AgentError.invalidURL }
        return try await client.performContainerAction(
            baseURL: url,
            containerID: containerID,
            action: action
        )
    }

    func killProcess(pid: Int32) async throws -> String {
        guard let server = selectedServer,
              let url = baseURL(for: server) else { throw AgentError.invalidURL }
        return try await client.killProcess(baseURL: url, pid: pid)
    }

    func refreshStats() async {
        guard let server = selectedServer,
              let url = baseURL(for: server) else { return }
        do {
            let response = try await client.fetchStats(baseURL: url)
            applyFullSnapshot(server: server, response: response)
        } catch {
            Self.log.error("Manual refresh failed for \(server.name): \(error.localizedDescription)")
        }
    }

    func restartAgent() async throws -> String {
        guard let server = selectedServer,
              let url = baseURL(for: server) else { throw AgentError.invalidURL }
        return try await client.restartAgent(baseURL: url)
    }

    /// Open (or reuse) an SSH tunnel to a remote service port for the given server.
    /// Used by container plugins to reach services running alongside the deskmon agent.
    func pluginTunnelURL(for serverID: UUID, remotePort: Int) async throws -> String {
        guard let ssh = sshManagers[serverID] else { throw SSHTunnelError.notConnected }
        return try await ssh.openExtraTunnel(remotePort: remotePort)
    }

    /// Execute a shell command on the given server over SSH and return its stdout.
    func executeCommand(_ command: String, on serverID: UUID) async throws -> String {
        guard let ssh = sshManagers[serverID] else { throw SSHTunnelError.notConnected }
        return try await ssh.executeCommand(command)
    }

    /// Execute a shell command on the currently selected server over SSH and return its stdout.
    func executeCommand(_ command: String) async throws -> String {
        guard let server = selectedServer,
              let ssh = sshManagers[server.id] else { throw SSHTunnelError.notConnected }
        return try await ssh.executeCommand(command)
    }

    // MARK: - Status Derivation

    private static func deriveStatus(from stats: ServerStats) -> ServerStatus {
        if stats.cpu.usagePercent > 90 || stats.memory.usagePercent > 95 {
            return .critical
        } else if stats.cpu.usagePercent > 75 || stats.memory.usagePercent > 85 {
            return .warning
        }
        return .healthy
    }
}
