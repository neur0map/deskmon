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

    private var pollingTask: Task<Void, Never>?

    var selectedServer: ServerInfo? {
        servers.first { $0.id == selectedServerID }
    }

    var currentStatus: ServerStatus {
        selectedServer?.status ?? .offline
    }

    init() {
        let homelab = ServerInfo(name: "Homelab", host: "192.168.1.100")
        let media = ServerInfo(name: "Media Server", host: "192.168.1.200")
        servers = [homelab, media]
        selectedServerID = homelab.id
        refreshData()
        startPolling()
    }

    func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(self?.pollingInterval ?? 3))
                } catch {
                    break
                }
                guard let self else { break }
                self.refreshData()
            }
        }
    }

    func stopPolling() {
        isPolling = false
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refreshData() {
        withAnimation(.easeInOut(duration: 0.5)) {
            for (index, server) in servers.enumerated() {
                let stats = MockDataProvider.generateStats(serverIndex: index)
                server.stats = stats
                server.status = MockDataProvider.generateStatus(from: stats)
                server.containers = MockDataProvider.generateContainers(serverIndex: index)
            }
        }
    }

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
}
