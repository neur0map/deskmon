import Foundation
import SwiftUI

struct DockerContainer: Identifiable, Codable, Sendable {
    var id: String
    var name: String
    var image: String
    var status: ContainerStatus
    var cpuPercent: Double
    var memoryUsageMB: Double
    var memoryLimitMB: Double
    var networkRxBytes: Int64
    var networkTxBytes: Int64
    var blockReadBytes: Int64
    var blockWriteBytes: Int64
    var pids: Int
    var startedAt: Date?

    // TODO: ports — [PortMapping] for exposed port mappings (e.g. 8080:80/tcp)
    // TODO: restartCount — number of times container has restarted
    // TODO: healthStatus — healthy/unhealthy/starting/none (requires container healthcheck)
    // TODO: healthLog — last health check output string

    var memoryPercent: Double {
        guard memoryLimitMB > 0 else { return 0 }
        return memoryUsageMB / memoryLimitMB * 100
    }

    var uptime: String? {
        guard let startedAt else { return nil }
        let seconds = Int(Date().timeIntervalSince(startedAt))
        return ByteFormatter.formatUptime(seconds)
    }

    enum ContainerStatus: String, Codable, Sendable {
        case running
        case stopped
        case restarting

        var label: String {
            rawValue.capitalized
        }

        var color: Color {
            switch self {
            case .running: Theme.healthy
            case .stopped: .secondary
            case .restarting: Theme.warning
            }
        }
    }
}
