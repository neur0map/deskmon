import Foundation
import os
import SwiftUI

@MainActor
@Observable
final class ServerManager {
    var servers: [ServerInfo] = []
    var selectedServerID: UUID?
    var isConnected = false

    private static let log = Logger(subsystem: "prowlsh.deskmon", category: "ServerManager")
    private let client = AgentClient.shared
    private var streamTasks: [UUID: Task<Void, Never>] = [:]

    var selectedServer: ServerInfo? {
        servers.first { $0.id == selectedServerID }
    }

    var currentStatus: ServerStatus {
        selectedServer?.status ?? .offline
    }

    // MARK: - Connection Verification

    /// Two-step handshake used by AddServerSheet / EditServerSheet before saving.
    func testConnection(host: String, port: Int, token: String) async -> ConnectionResult {
        await client.verifyConnection(host: host, port: port, token: token)
    }

    // MARK: - SSE Streaming

    /// Starts an SSE stream for every server that doesn't already have one.
    func startStreaming() {
        for server in servers {
            guard streamTasks[server.id] == nil else { continue }
            startStream(for: server)
        }
    }

    /// Stops all SSE streams.
    func stopStreaming() {
        for (_, task) in streamTasks {
            task.cancel()
        }
        streamTasks.removeAll()
        isConnected = false
    }

    /// Starts (or restarts) the SSE stream for a single server.
    private func startStream(for server: ServerInfo) {
        streamTasks[server.id]?.cancel()

        streamTasks[server.id] = Task {
            let serverID = server.id
            var backoff: UInt64 = 2

            while !Task.isCancelled {
                // Step 1: Fetch full snapshot to fill UI immediately
                do {
                    let response = try await client.fetchStats(
                        host: server.host, port: server.port, token: server.token
                    )
                    applyFullSnapshot(server: server, response: response)
                } catch let error as AgentError where error == .unauthorized {
                    Self.log.error("Fetch unauthorized for \(server.name)")
                    withAnimation { server.status = .unauthorized }
                    try? await Task.sleep(for: .seconds(backoff))
                    backoff = min(backoff * 2, 30)
                    continue
                } catch {
                    Self.log.error("Fetch failed for \(server.name): \(error.localizedDescription)")
                    withAnimation { server.status = .offline }
                    try? await Task.sleep(for: .seconds(backoff))
                    backoff = min(backoff * 2, 30)
                    continue
                }

                // Step 2: Open SSE stream for live updates
                let stream = client.streamStats(
                    host: server.host, port: server.port, token: server.token
                )

                do {
                    for try await event in stream {
                        guard !Task.isCancelled else { break }

                        backoff = 2 // Reset backoff on successful event

                        switch event {
                        case .system(let stats, let processes):
                            withAnimation(.easeInOut(duration: 0.4)) {
                                server.stats = stats
                                server.processes = processes
                                server.appendNetworkSample(stats.network)
                                server.status = Self.deriveStatus(from: stats)
                            }
                            if serverID == selectedServerID {
                                isConnected = true
                            }

                        case .docker(let containers):
                            withAnimation(.easeInOut(duration: 0.5)) {
                                server.containers = containers
                            }

                        case .services(let services):
                            withAnimation(.easeInOut(duration: 0.5)) {
                                server.services = services
                            }

                        case .keepalive:
                            break
                        }
                    }
                } catch {
                    Self.log.error("SSE stream error for \(server.name): \(error.localizedDescription)")
                }

                guard !Task.isCancelled else { break }

                // Mark disconnected, wait, then retry
                withAnimation { server.status = .offline }
                if serverID == selectedServerID {
                    isConnected = false
                }

                try? await Task.sleep(for: .seconds(backoff))
                backoff = min(backoff * 2, 30)
            }
        }
    }

    /// Applies a full GET /stats response to the server (used on connect/reconnect).
    private func applyFullSnapshot(server: ServerInfo, response: AgentStatsResponse) {
        withAnimation(.easeInOut(duration: 0.5)) {
            server.stats = response.system
            server.containers = response.containers
            server.processes = response.processes ?? []
            server.services = response.services ?? []
            server.appendNetworkSample(response.system.network)
            server.status = Self.deriveStatus(from: response.system)
        }
    }

    // MARK: - Server Management

    func addServer(name: String, host: String, port: Int, token: String) {
        let server = ServerInfo(name: name, host: host, port: port, token: token)
        servers.append(server)
        if selectedServerID == nil {
            selectedServerID = server.id
        }
        startStream(for: server)
    }

    func updateServer(id: UUID, name: String, host: String, port: Int, token: String) {
        guard let server = servers.first(where: { $0.id == id }) else { return }
        server.name = name
        server.host = host
        server.port = port
        server.token = token
        // Restart stream with new credentials
        startStream(for: server)
    }

    func deleteServer(_ server: ServerInfo) {
        streamTasks[server.id]?.cancel()
        streamTasks.removeValue(forKey: server.id)
        servers.removeAll { $0.id == server.id }
        if selectedServerID == server.id {
            selectedServerID = servers.first?.id
        }
    }

    func selectServer(_ server: ServerInfo) {
        selectedServerID = server.id
        // Update connection status based on selected server
        isConnected = server.status != .offline && server.status != .unauthorized
    }

    // MARK: - Container Actions

    func performContainerAction(containerID: String, action: ContainerAction) async throws -> String {
        guard let server = selectedServer else { throw AgentError.invalidURL }
        let result = try await client.performContainerAction(
            host: server.host,
            port: server.port,
            token: server.token,
            containerID: containerID,
            action: action
        )
        // Docker stats will update via the SSE stream automatically
        return result
    }

    func killProcess(pid: Int32) async throws -> String {
        guard let server = selectedServer else { throw AgentError.invalidURL }
        return try await client.killProcess(
            host: server.host,
            port: server.port,
            token: server.token,
            pid: pid
        )
        // Process list will update via the SSE stream automatically
    }

    func configureService(pluginId: String, password: String) async throws -> String {
        guard let server = selectedServer else { throw AgentError.invalidURL }
        return try await client.configureService(
            host: server.host,
            port: server.port,
            token: server.token,
            pluginId: pluginId,
            password: password
        )
    }

    func restartAgent() async throws -> String {
        guard let server = selectedServer else { throw AgentError.invalidURL }
        return try await client.restartAgent(
            host: server.host,
            port: server.port,
            token: server.token
        )
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
