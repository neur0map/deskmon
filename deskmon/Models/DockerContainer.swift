import Foundation
import SwiftUI

// MARK: - Port Mapping

struct PortMapping: Codable, Identifiable, Sendable {
    let hostPort: Int
    let containerPort: Int
    let `protocol`: String

    var id: String { "\(hostPort)-\(containerPort)-\(`protocol`)" }
}

// MARK: - Health Check Status

enum HealthCheckStatus: String, Codable, Sendable {
    case healthy, unhealthy, starting, none

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .healthy: Theme.healthy
        case .unhealthy: Theme.critical
        case .starting: Theme.warning
        case .none: .secondary
        }
    }

    var systemImage: String {
        switch self {
        case .healthy: "heart.fill"
        case .unhealthy: "heart.slash.fill"
        case .starting: "heart.circle"
        case .none: "heart"
        }
    }
}

// MARK: - Docker Container

struct DockerContainer: Identifiable, Sendable {
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
    var ports: [PortMapping]
    var restartCount: Int
    var healthStatus: HealthCheckStatus

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

// MARK: - Codable

/// Custom Codable because the agent sends `startedAt` as an ISO 8601 string
/// (or empty string for stopped containers), but Swift expects `Date?`.
extension DockerContainer: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, image, status, cpuPercent, memoryUsageMB, memoryLimitMB
        case networkRxBytes, networkTxBytes, blockReadBytes, blockWriteBytes
        case pids, startedAt, ports, restartCount, healthStatus
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        image = try c.decode(String.self, forKey: .image)
        status = try c.decode(ContainerStatus.self, forKey: .status)
        cpuPercent = try c.decode(Double.self, forKey: .cpuPercent)
        memoryUsageMB = try c.decode(Double.self, forKey: .memoryUsageMB)
        memoryLimitMB = try c.decode(Double.self, forKey: .memoryLimitMB)
        networkRxBytes = try c.decode(Int64.self, forKey: .networkRxBytes)
        networkTxBytes = try c.decode(Int64.self, forKey: .networkTxBytes)
        blockReadBytes = try c.decode(Int64.self, forKey: .blockReadBytes)
        blockWriteBytes = try c.decode(Int64.self, forKey: .blockWriteBytes)
        pids = try c.decode(Int.self, forKey: .pids)

        // Agent sends ISO 8601 string, empty string, or null
        if let dateString = try c.decodeIfPresent(String.self, forKey: .startedAt),
           !dateString.isEmpty {
            startedAt = ISO8601DateFormatter().date(from: dateString)
        } else {
            startedAt = nil
        }

        // New fields — use defaults for backward compatibility
        ports = (try? c.decode([PortMapping].self, forKey: .ports)) ?? []
        restartCount = (try? c.decode(Int.self, forKey: .restartCount)) ?? 0
        healthStatus = HealthCheckStatus(rawValue: (try? c.decode(String.self, forKey: .healthStatus)) ?? "none") ?? .none
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(image, forKey: .image)
        try c.encode(status, forKey: .status)
        try c.encode(cpuPercent, forKey: .cpuPercent)
        try c.encode(memoryUsageMB, forKey: .memoryUsageMB)
        try c.encode(memoryLimitMB, forKey: .memoryLimitMB)
        try c.encode(networkRxBytes, forKey: .networkRxBytes)
        try c.encode(networkTxBytes, forKey: .networkTxBytes)
        try c.encode(blockReadBytes, forKey: .blockReadBytes)
        try c.encode(blockWriteBytes, forKey: .blockWriteBytes)
        try c.encode(pids, forKey: .pids)
        if let startedAt {
            try c.encode(ISO8601DateFormatter().string(from: startedAt), forKey: .startedAt)
        } else {
            try c.encodeNil(forKey: .startedAt)
        }
        try c.encode(ports, forKey: .ports)
        try c.encode(restartCount, forKey: .restartCount)
        try c.encode(healthStatus.rawValue, forKey: .healthStatus)
    }
}
