import SwiftUI

struct SystemStatsView: View {
    let stats: ServerStats

    var body: some View {
        VStack(spacing: 6) {
            StatCardView(
                title: "CPU",
                value: String(format: "%.1f%%", stats.cpu.usagePercent),
                percent: stats.cpu.usagePercent,
                icon: "cpu",
                tint: Theme.cpu,
                tintLight: Theme.cpuLight
            )

            StatCardView(
                title: "Memory",
                value: String(format: "%.1f%%", stats.memory.usagePercent),
                percent: stats.memory.usagePercent,
                icon: "memorychip",
                tint: Theme.memory,
                tintLight: Theme.memoryLight
            )

            StatCardView(
                title: "Disk",
                value: String(format: "%.1f%%", stats.disk.usagePercent),
                percent: stats.disk.usagePercent,
                icon: "internaldrive",
                tint: Theme.disk,
                tintLight: Theme.diskLight
            )
        }
        .padding(10)
        .cardStyle(cornerRadius: 16)
    }
}
