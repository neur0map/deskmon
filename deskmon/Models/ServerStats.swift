import Foundation

struct CPUStats: Codable, Sendable {
    var usagePercent: Double
    var coreCount: Int
    var temperature: Double
    var temperatureAvailable: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        usagePercent = try c.decode(Double.self, forKey: .usagePercent)
        coreCount = try c.decode(Int.self, forKey: .coreCount)
        temperature = try c.decode(Double.self, forKey: .temperature)
        temperatureAvailable = (try? c.decode(Bool.self, forKey: .temperatureAvailable)) ?? true
    }
}

struct MemoryStats: Codable, Sendable {
    var usedBytes: Int64
    var totalBytes: Int64

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}

struct DiskInfo: Codable, Identifiable, Sendable {
    var mountPoint: String
    var device: String
    var fsType: String
    var usedBytes: Int64
    var totalBytes: Int64

    var id: String { mountPoint }

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    /// Short label for display — last path component, or "/" for root.
    var label: String {
        if mountPoint == "/" { return "/" }
        return (mountPoint as NSString).lastPathComponent
    }
}

struct InterfaceStats: Codable, Sendable {
    var downloadBytesPerSec: Double
    var uploadBytesPerSec: Double
    var rxErrors: UInt64
    var rxDrops: UInt64
    var txErrors: UInt64
    var txDrops: UInt64

    init(downloadBytesPerSec: Double, uploadBytesPerSec: Double,
         rxErrors: UInt64 = 0, rxDrops: UInt64 = 0,
         txErrors: UInt64 = 0, txDrops: UInt64 = 0) {
        self.downloadBytesPerSec = downloadBytesPerSec
        self.uploadBytesPerSec = uploadBytesPerSec
        self.rxErrors = rxErrors
        self.rxDrops = rxDrops
        self.txErrors = txErrors
        self.txDrops = txDrops
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        downloadBytesPerSec = try c.decode(Double.self, forKey: .downloadBytesPerSec)
        uploadBytesPerSec = try c.decode(Double.self, forKey: .uploadBytesPerSec)
        rxErrors = (try? c.decode(UInt64.self, forKey: .rxErrors)) ?? 0
        rxDrops = (try? c.decode(UInt64.self, forKey: .rxDrops)) ?? 0
        txErrors = (try? c.decode(UInt64.self, forKey: .txErrors)) ?? 0
        txDrops = (try? c.decode(UInt64.self, forKey: .txDrops)) ?? 0
    }

    var hasErrors: Bool {
        rxErrors > 0 || rxDrops > 0 || txErrors > 0 || txDrops > 0
    }

    var totalErrors: UInt64 { rxErrors + txErrors }
    var totalDrops: UInt64 { rxDrops + txDrops }
}

struct NetworkReport: Codable, Sendable {
    var physical: InterfaceStats
    var virtual: InterfaceStats?
}

struct ServerStats: Sendable {
    var cpu: CPUStats
    var memory: MemoryStats
    var disks: [DiskInfo]
    var network: NetworkReport
    var uptimeSeconds: Int
}

// MARK: - Codable with backward compat

extension ServerStats: Codable {
    private enum CodingKeys: String, CodingKey {
        case cpu, memory, disks, disk, network, uptimeSeconds
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cpu, forKey: .cpu)
        try c.encode(memory, forKey: .memory)
        try c.encode(disks, forKey: .disks)
        try c.encode(network, forKey: .network)
        try c.encode(uptimeSeconds, forKey: .uptimeSeconds)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cpu = try c.decode(CPUStats.self, forKey: .cpu)
        memory = try c.decode(MemoryStats.self, forKey: .memory)
        uptimeSeconds = try c.decode(Int.self, forKey: .uptimeSeconds)

        // Disks: try new array format first, fall back to old single disk
        if let diskArray = try? c.decode([DiskInfo].self, forKey: .disks) {
            disks = diskArray
        } else if let oldDisk = try? c.decode(OldDiskStats.self, forKey: .disk) {
            disks = [DiskInfo(
                mountPoint: "/",
                device: "",
                fsType: "",
                usedBytes: oldDisk.usedBytes,
                totalBytes: oldDisk.totalBytes
            )]
        } else {
            disks = []
        }

        // Network: try new report format first, fall back to old flat format
        if let report = try? c.decode(NetworkReport.self, forKey: .network) {
            network = report
        } else if let oldNet = try? c.decode(OldNetworkStats.self, forKey: .network) {
            network = NetworkReport(
                physical: InterfaceStats(
                    downloadBytesPerSec: oldNet.downloadBytesPerSec,
                    uploadBytesPerSec: oldNet.uploadBytesPerSec,
                    rxErrors: 0, rxDrops: 0, txErrors: 0, txDrops: 0
                ),
                virtual: nil
            )
        } else {
            network = NetworkReport(
                physical: InterfaceStats(
                    downloadBytesPerSec: 0, uploadBytesPerSec: 0,
                    rxErrors: 0, rxDrops: 0, txErrors: 0, txDrops: 0
                ),
                virtual: nil
            )
        }
    }
}

// MARK: - Backward compat types (old agent format)

private struct OldDiskStats: Codable {
    var usedBytes: Int64
    var totalBytes: Int64
}

private struct OldNetworkStats: Codable {
    var downloadBytesPerSec: Double
    var uploadBytesPerSec: Double
}
