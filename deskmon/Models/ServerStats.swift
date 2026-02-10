import Foundation

struct CPUStats: Codable, Sendable {
    var usagePercent: Double
    var coreCount: Int
    var temperature: Double
}

struct MemoryStats: Codable, Sendable {
    var usedBytes: Int64
    var totalBytes: Int64

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}

struct DiskStats: Codable, Sendable {
    var usedBytes: Int64
    var totalBytes: Int64

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}

struct NetworkStats: Codable, Sendable {
    var downloadBytesPerSec: Double
    var uploadBytesPerSec: Double
}

struct ServerStats: Codable, Sendable {
    var cpu: CPUStats
    var memory: MemoryStats
    var disk: DiskStats
    var network: NetworkStats
    var uptimeSeconds: Int
}
