import Foundation

enum ByteFormatter {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter
    }()

    private static let speedFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter
    }()

    static func format(_ bytes: Int64) -> String {
        byteFormatter.string(fromByteCount: bytes)
    }

    static func formatSpeed(_ bytesPerSecond: Double) -> String {
        speedFormatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }

    static func formatUptime(_ seconds: Int) -> String {
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            let minutes = (seconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        } else {
            let minutes = seconds / 60
            return "\(minutes)m"
        }
    }
}
