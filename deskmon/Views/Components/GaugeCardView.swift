import SwiftUI

/// Unified system metrics card — replaces the three circular gauge cards
/// with a single Activity-Monitor-style card containing horizontal bars.
/// Bars animate at 60fps via TimelineView for smooth, continuous motion.
struct SystemMetricsCard: View {
    let stats: ServerStats

    var body: some View {
        VStack(spacing: 0) {
            MetricRow(
                icon: "cpu",
                title: "CPU",
                percent: stats.cpu.usagePercent,
                subtitle: cpuSubtitle,
                tint: Theme.cpu,
                tintLight: Theme.cpuLight
            )

            Divider()
                .background(Theme.cardBorder)
                .padding(.horizontal, 14)

            MetricRow(
                icon: "memorychip",
                title: "Memory",
                percent: stats.memory.usagePercent,
                subtitle: "\(ByteFormatter.format(stats.memory.usedBytes)) / \(ByteFormatter.format(stats.memory.totalBytes))",
                tint: Theme.memory,
                tintLight: Theme.memoryLight
            )

            ForEach(stats.disks) { disk in
                Divider()
                    .background(Theme.cardBorder)
                    .padding(.horizontal, 14)

                MetricRow(
                    icon: "internaldrive",
                    title: disk.label,
                    percent: disk.usagePercent,
                    subtitle: "\(ByteFormatter.format(disk.usedBytes)) / \(ByteFormatter.format(disk.totalBytes))",
                    tint: diskTint(disk.usagePercent),
                    tintLight: diskTintLight(disk.usagePercent)
                )
            }
        }
        .cardStyle(cornerRadius: 16)
    }

    private var cpuSubtitle: String {
        if stats.cpu.temperatureAvailable {
            return "\(stats.cpu.coreCount) cores · \(Int(stats.cpu.temperature))°C"
        }
        return "\(stats.cpu.coreCount) cores"
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

// MARK: - Metric Row

private struct MetricRow: View {
    let icon: String
    let title: String
    let percent: Double
    let subtitle: String
    let tint: Color
    let tintLight: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label + percentage
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(String(format: "%.1f%%", percent))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText())
            }

            // Animated horizontal bar
            SmoothBar(percent: percent, tint: tint, tintLight: tintLight)

            // Subtitle
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Smooth Bar

/// A horizontal progress bar that uses SwiftUI's native spring animation
/// for buttery-smooth transitions. The spring retargets mid-flight when
/// new values arrive, so rapid CPU fluctuations blend naturally.
private struct SmoothBar: View {
    let percent: Double
    let tint: Color
    let tintLight: Color

    private var fraction: Double {
        min(max(percent / 100, 0), 1)
    }

    private var barFill: some ShapeStyle {
        if percent > 90 {
            return AnyShapeStyle(
                LinearGradient(colors: [Theme.critical, Theme.critical.opacity(0.7)],
                               startPoint: .leading, endPoint: .trailing)
            )
        }
        if percent > 75 {
            return AnyShapeStyle(
                LinearGradient(colors: [Theme.warning, Theme.warning.opacity(0.7)],
                               startPoint: .leading, endPoint: .trailing)
            )
        }
        return AnyShapeStyle(
            LinearGradient(colors: [tint, tintLight],
                           startPoint: .leading, endPoint: .trailing)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))

                Capsule()
                    .fill(barFill)
                    .frame(width: max(geo.size.width * fraction, 0))
                    .animation(.smooth(duration: 0.8), value: fraction)
            }
        }
        .frame(height: 5)
    }
}
