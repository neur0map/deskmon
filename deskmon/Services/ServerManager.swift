import Foundation
import SwiftUI

@MainActor
@Observable
final class ServerManager {
    var servers: [ServerInfo] = []
    var selectedServerID: UUID?
    var isPolling = false
    var pollingInterval: TimeInterval = 3 {
        didSet {
            guard oldValue != pollingInterval, isPolling else { return }
            stopPolling()
            startPolling()
        }
    }

    static let intervalOptions: [(label: String, value: TimeInterval)] = [
        ("1s", 1), ("3s", 3), ("5s", 5), ("10s", 10), ("30s", 30), ("60s", 60)
    ]

    private let client = AgentClient.shared
    private var pollingTask: Task<Void, Never>?

    var selectedServer: ServerInfo? {
        servers.first { $0.id == selectedServerID }
    }

    var currentStatus: ServerStatus {
        selectedServer?.status ?? .offline
    }

    init() {
        startPolling()
    }

    // MARK: - Connection Verification

    /// Two-step handshake used by AddServerSheet / EditServerSheet before saving.
    func testConnection(host: String, port: Int, token: String) async -> ConnectionResult {
        await client.verifyConnection(host: host, port: port, token: token)
    }

    // MARK: - Polling

    func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let start = ContinuousClock.now
                await self.refreshData()
                let elapsed = ContinuousClock.now - start
                let target = Duration.seconds(self.pollingInterval)
                let remaining = target - elapsed
                if remaining > .zero {
                    do {
                        try await Task.sleep(for: remaining)
                    } catch {
                        break
                    }
                }
            }
        }
    }

    func stopPolling() {
        isPolling = false
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Data Fetching

    /// Polls each server with a single GET /stats request.
    /// Uses fetchStats directly — no health check per cycle.
    func refreshData() async {
        guard !servers.isEmpty else { return }

        let connections = servers.map { server in
            (id: server.id, host: server.host, port: server.port, token: server.token)
        }

        await withTaskGroup(of: (UUID, FetchResult).self) { group in
            for conn in connections {
                group.addTask { [client] in
                    do {
                        let response = try await client.fetchStats(
                            host: conn.host, port: conn.port, token: conn.token
                        )
                        return (conn.id, .success(response))
                    } catch let error as AgentError where error == .unauthorized {
                        return (conn.id, .unauthorized)
                    } catch {
                        return (conn.id, .offline)
                    }
                }
            }

            for await (id, result) in group {
                guard let server = servers.first(where: { $0.id == id }) else { continue }
                withAnimation(.easeInOut(duration: 0.5)) {
                    switch result {
                    case .success(let response):
                        server.stats = response.system
                        server.containers = response.containers
                        server.processes = response.processes ?? []
                        server.appendNetworkSample(response.system.network)
                        server.status = Self.deriveStatus(from: response.system)
                    case .unauthorized:
                        server.status = .unauthorized
                    case .offline:
                        server.status = .offline
                    }
                }
            }
        }
    }

    // MARK: - Server Management

    func addServer(name: String, host: String, port: Int, token: String) {
        let server = ServerInfo(name: name, host: host, port: port, token: token)
        servers.append(server)
        if selectedServerID == nil {
            selectedServerID = server.id
        }
    }

    func updateServer(id: UUID, name: String, host: String, port: Int, token: String) {
        guard let server = servers.first(where: { $0.id == id }) else { return }
        server.name = name
        server.host = host
        server.port = port
        server.token = token
    }

    func deleteServer(_ server: ServerInfo) {
        servers.removeAll { $0.id == server.id }
        if selectedServerID == server.id {
            selectedServerID = servers.first?.id
        }
    }

    func selectServer(_ server: ServerInfo) {
        selectedServerID = server.id
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
        await refreshData()
        return result
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

// MARK: - Fetch Result (internal to polling)

private enum FetchResult: Sendable {
    case success(AgentStatsResponse)
    case unauthorized
    case offline
}
