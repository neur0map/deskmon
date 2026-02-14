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

            ForEach(stats.disks) { disk in
                StatCardView(
                    title: disk.label,
                    value: String(format: "%.1f%%", disk.usagePercent),
                    percent: disk.usagePercent,
                    icon: "internaldrive",
                    tint: diskTint(disk.usagePercent),
                    tintLight: diskTintLight(disk.usagePercent)
                )
            }
        }
        .padding(10)
        .cardStyle(cornerRadius: 16)
    }

    private func diskTint(_ percent: Double) -> Color {
        if percent > 90 { return Theme.critical }
        if percent > 75 { return Theme.warning }
        return Theme.disk
    }

    private func diskTintLight(_ percent: Double) -> Color {
        if percent > 90 { return Theme.critical.opacity(0.7) }
        if percent > 75 { return Theme.warning.opacity(0.7) }
        return Theme.diskLight
    }
}
