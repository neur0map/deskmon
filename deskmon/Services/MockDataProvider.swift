import Foundation

enum MockDataProvider {
    private static let startTime = Date()

    static func generateStats(serverIndex: Int = 0) -> ServerStats {
        let elapsed = Date().timeIntervalSince(startTime)
        let offset = Double(serverIndex) * 50

        let cpuBase: Double
        let ramBase: Double
        let diskPercent: Double
        let downloadBase: Double
        let uploadBase: Double
        let coreCount: Int
        let totalRAM: Int64
        let totalDisk: Int64
        let uptimeSeconds: Int

        switch serverIndex {
        case 0:
            cpuBase = 42.0 + 18.0 * sin((elapsed + offset) / 10.0)
            ramBase = 65.0 + 8.0 * sin((elapsed + offset) / 30.0)
            diskPercent = 52.0 + 3.0 * sin(elapsed / 120.0)
            downloadBase = 5.0 + 8.0 * abs(sin((elapsed + offset) / 8.0))
            uploadBase = 1.0 + 2.0 * abs(sin((elapsed + offset) / 12.0))
            coreCount = 8
            totalRAM = 32 * 1024 * 1024 * 1024
            totalDisk = 500 * 1024 * 1024 * 1024
            uptimeSeconds = 12 * 86400 + 7 * 3600 + 42 * 60
        case 1:
            cpuBase = 58.0 + 22.0 * sin((elapsed + offset) / 8.0)
            ramBase = 76.0 + 10.0 * sin((elapsed + offset) / 25.0)
            diskPercent = 71.0 + 2.0 * sin(elapsed / 100.0)
            downloadBase = 12.0 + 15.0 * abs(sin((elapsed + offset) / 6.0))
            uploadBase = 3.0 + 5.0 * abs(sin((elapsed + offset) / 10.0))
            coreCount = 12
            totalRAM = 64 * 1024 * 1024 * 1024
            totalDisk = 2 * 1024 * 1024 * 1024 * 1024
            uptimeSeconds = 45 * 86400 + 3 * 3600 + 18 * 60
        default:
            cpuBase = 30.0
            ramBase = 50.0
            diskPercent = 40.0
            downloadBase = 2.0
            uploadBase = 0.5
            coreCount = 4
            totalRAM = 16 * 1024 * 1024 * 1024
            totalDisk = 256 * 1024 * 1024 * 1024
            uptimeSeconds = 86400
        }

        let cpuNoise = Double.random(in: -5...5)
        let cpuSpike = Double.random(in: 0...1) > 0.95 ? Double.random(in: 20...35) : 0
        let cpuUsage = min(100, max(0, cpuBase + cpuNoise + cpuSpike))

        let ramNoise = Double.random(in: -2...2)
        let ramPercent = min(100, max(0, ramBase + ramNoise))
        let usedRAM = Int64(Double(totalRAM) * ramPercent / 100.0)

        let diskFinal = min(100, max(0, diskPercent + Double.random(in: -0.5...0.5)))
        let usedDisk = Int64(Double(totalDisk) * diskFinal / 100.0)

        let downloadNoise = Double.random(in: -2...4)
        let downloadMBps = max(0.1, downloadBase + downloadNoise)

        let uploadNoise = Double.random(in: -0.5...1)
        let uploadMBps = max(0.05, uploadBase + uploadNoise)

        return ServerStats(
            cpu: CPUStats(
                usagePercent: cpuUsage,
                coreCount: coreCount,
                temperature: 50 + cpuUsage * 0.35 + Double.random(in: -2...2)
            ),
            memory: MemoryStats(usedBytes: usedRAM, totalBytes: totalRAM),
            disk: DiskStats(usedBytes: usedDisk, totalBytes: totalDisk),
            network: NetworkStats(
                downloadBytesPerSec: downloadMBps * 1024 * 1024,
                uploadBytesPerSec: uploadMBps * 1024 * 1024
            ),
            uptimeSeconds: uptimeSeconds
        )
    }

    static func generateContainers(serverIndex: Int = 0) -> [DockerContainer] {
        let baseDate = Date().addingTimeInterval(-26 * 86400 - 4 * 3600) // ~26 days ago

        switch serverIndex {
        case 0:
            return [
                DockerContainer(id: "c1a2b3", name: "pihole", image: "pihole/pihole:latest", status: .running,
                    cpuPercent: Double.random(in: 0.5...3.0), memoryUsageMB: Double.random(in: 120...180), memoryLimitMB: 512,
                    networkRxBytes: 1_048_576_000 + Int64.random(in: 0...10_000_000), networkTxBytes: 524_288_000 + Int64.random(in: 0...5_000_000),
                    blockReadBytes: 2_147_483_648, blockWriteBytes: 536_870_912, pids: Int.random(in: 10...15),
                    startedAt: baseDate),
                DockerContainer(id: "d4e5f6", name: "plex", image: "plexinc/pms-docker:latest", status: .running,
                    cpuPercent: Double.random(in: 5...25), memoryUsageMB: Double.random(in: 400...800), memoryLimitMB: 2048,
                    networkRxBytes: 15_032_385_536 + Int64.random(in: 0...50_000_000), networkTxBytes: 8_589_934_592 + Int64.random(in: 0...20_000_000),
                    blockReadBytes: 10_737_418_240, blockWriteBytes: 4_294_967_296, pids: Int.random(in: 25...40),
                    startedAt: baseDate.addingTimeInterval(3600)),
                DockerContainer(id: "g7h8i9", name: "homebridge", image: "homebridge/homebridge:latest", status: .running,
                    cpuPercent: Double.random(in: 0.2...2.0), memoryUsageMB: Double.random(in: 80...150), memoryLimitMB: 256,
                    networkRxBytes: 104_857_600 + Int64.random(in: 0...1_000_000), networkTxBytes: 52_428_800 + Int64.random(in: 0...500_000),
                    blockReadBytes: 268_435_456, blockWriteBytes: 134_217_728, pids: Int.random(in: 5...10),
                    startedAt: baseDate.addingTimeInterval(7200)),
                DockerContainer(id: "j1k2l3", name: "jellyfin", image: "jellyfin/jellyfin:latest", status: .running,
                    cpuPercent: Double.random(in: 2...15), memoryUsageMB: Double.random(in: 300...600), memoryLimitMB: 1024,
                    networkRxBytes: 5_368_709_120 + Int64.random(in: 0...30_000_000), networkTxBytes: 3_221_225_472 + Int64.random(in: 0...15_000_000),
                    blockReadBytes: 5_368_709_120, blockWriteBytes: 2_147_483_648, pids: Int.random(in: 18...30),
                    startedAt: baseDate.addingTimeInterval(1800)),
                DockerContainer(id: "m4n5o6", name: "homeassistant", image: "ghcr.io/home-assistant/home-assistant:stable", status: .running,
                    cpuPercent: Double.random(in: 1...8), memoryUsageMB: Double.random(in: 200...400), memoryLimitMB: 768,
                    networkRxBytes: 2_684_354_560 + Int64.random(in: 0...5_000_000), networkTxBytes: 1_073_741_824 + Int64.random(in: 0...2_000_000),
                    blockReadBytes: 3_221_225_472, blockWriteBytes: 1_610_612_736, pids: Int.random(in: 15...25),
                    startedAt: baseDate.addingTimeInterval(600)),
                DockerContainer(id: "p7q8r9", name: "nginx", image: "nginx:alpine", status: .stopped,
                    cpuPercent: 0, memoryUsageMB: 0, memoryLimitMB: 128,
                    networkRxBytes: 0, networkTxBytes: 0,
                    blockReadBytes: 0, blockWriteBytes: 0, pids: 0,
                    startedAt: nil),
            ]
        case 1:
            return [
                DockerContainer(id: "s1t2u3", name: "plex", image: "plexinc/pms-docker:latest", status: .running,
                    cpuPercent: Double.random(in: 15...45), memoryUsageMB: Double.random(in: 800...1500), memoryLimitMB: 4096,
                    networkRxBytes: 42_949_672_960 + Int64.random(in: 0...100_000_000), networkTxBytes: 21_474_836_480 + Int64.random(in: 0...50_000_000),
                    blockReadBytes: 32_212_254_720, blockWriteBytes: 10_737_418_240, pids: Int.random(in: 30...50),
                    startedAt: baseDate.addingTimeInterval(-19 * 86400)),
                DockerContainer(id: "v4w5x6", name: "jellyfin", image: "jellyfin/jellyfin:latest", status: .running,
                    cpuPercent: Double.random(in: 5...20), memoryUsageMB: Double.random(in: 400...900), memoryLimitMB: 2048,
                    networkRxBytes: 10_737_418_240 + Int64.random(in: 0...40_000_000), networkTxBytes: 6_442_450_944 + Int64.random(in: 0...20_000_000),
                    blockReadBytes: 8_589_934_592, blockWriteBytes: 4_294_967_296, pids: Int.random(in: 20...35),
                    startedAt: baseDate.addingTimeInterval(-19 * 86400 + 3600)),
                DockerContainer(id: "y7z8a1", name: "sonarr", image: "linuxserver/sonarr:latest", status: .running,
                    cpuPercent: Double.random(in: 1...5), memoryUsageMB: Double.random(in: 150...300), memoryLimitMB: 512,
                    networkRxBytes: 1_073_741_824 + Int64.random(in: 0...5_000_000), networkTxBytes: 536_870_912 + Int64.random(in: 0...2_000_000),
                    blockReadBytes: 2_147_483_648, blockWriteBytes: 1_073_741_824, pids: Int.random(in: 8...15),
                    startedAt: baseDate.addingTimeInterval(-19 * 86400 + 7200)),
                DockerContainer(id: "b2c3d4", name: "radarr", image: "linuxserver/radarr:latest", status: .running,
                    cpuPercent: Double.random(in: 1...5), memoryUsageMB: Double.random(in: 150...300), memoryLimitMB: 512,
                    networkRxBytes: 1_073_741_824 + Int64.random(in: 0...5_000_000), networkTxBytes: 536_870_912 + Int64.random(in: 0...2_000_000),
                    blockReadBytes: 2_147_483_648, blockWriteBytes: 1_073_741_824, pids: Int.random(in: 8...15),
                    startedAt: baseDate.addingTimeInterval(-19 * 86400 + 10800)),
                DockerContainer(id: "e5f6g7", name: "transmission", image: "linuxserver/transmission:latest", status: .running,
                    cpuPercent: Double.random(in: 2...12), memoryUsageMB: Double.random(in: 100...250), memoryLimitMB: 384,
                    networkRxBytes: 85_899_345_920 + Int64.random(in: 0...200_000_000), networkTxBytes: 42_949_672_960 + Int64.random(in: 0...100_000_000),
                    blockReadBytes: 64_424_509_440, blockWriteBytes: 32_212_254_720, pids: Int.random(in: 5...12),
                    startedAt: baseDate.addingTimeInterval(-19 * 86400 + 1800)),
            ]
        default:
            return []
        }
    }

    static func generateStatus(from stats: ServerStats) -> ServerStatus {
        if stats.cpu.usagePercent > 90 || stats.memory.usagePercent > 95 {
            return .critical
        } else if stats.cpu.usagePercent > 75 || stats.memory.usagePercent > 85 {
            return .warning
        }
        return .healthy
    }
}
