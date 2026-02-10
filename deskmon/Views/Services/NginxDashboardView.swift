import SwiftUI

struct NginxDashboardView: View {
    let service: ServiceInfo

    private var accent: Color { serviceAccent(for: "nginx") }

    private var activeConnections: Int64 { service.stats["activeConnections"]?.intValue ?? 0 }
    private var accepts: Int64 { service.stats["accepts"]?.intValue ?? 0 }
    private var handled: Int64 { service.stats["handled"]?.intValue ?? 0 }
    private var requests: Int64 { service.stats["requests"]?.intValue ?? 0 }
    private var reading: Int64 { service.stats["reading"]?.intValue ?? 0 }
    private var writing: Int64 { service.stats["writing"]?.intValue ?? 0 }
    private var waiting: Int64 { service.stats["waiting"]?.intValue ?? 0 }
    private var dropped: Int64 { service.stats["dropped"]?.intValue ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                connectionsGrid
                trafficCard
                workerCard
            }
            .padding(20)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: service.icon)
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.title3.weight(.semibold))
                HStack(spacing: 6) {
                    Circle()
                        .fill(service.isRunning ? Theme.healthy : Theme.critical)
                        .frame(width: 8, height: 8)
                    Text(service.status.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .tintedCardStyle(cornerRadius: 12, tint: accent)
    }

    // MARK: - Connections Grid

    private var connectionsGrid: some View {
        HStack(spacing: 12) {
            statTile("Active", value: "\(activeConnections)", icon: "bolt.fill", tint: accent)
            statTile("Reading", value: "\(reading)", icon: "arrow.down.circle", tint: Theme.memory)
            statTile("Writing", value: "\(writing)", icon: "arrow.up.circle", tint: Theme.warning)
            statTile("Waiting", value: "\(waiting)", icon: "clock", tint: Theme.disk)
        }
    }

    private func statTile(_ label: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint.opacity(0.8))

            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cardStyle(cornerRadius: 12)
    }

    // MARK: - Traffic

    private var trafficCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lifetime Traffic")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                infoRow("Total Requests", value: formatLargeNumber(requests))
                Divider().padding(.leading, 12)
                infoRow("Accepted Connections", value: formatLargeNumber(accepts))
                Divider().padding(.leading, 12)
                infoRow("Handled Connections", value: formatLargeNumber(handled))
                Divider().padding(.leading, 12)
                infoRow("Dropped Connections", value: formatLargeNumber(dropped), warn: dropped > 0)
            }
            .cardStyle(cornerRadius: 12)
        }
    }

    // MARK: - Worker Breakdown

    private var workerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Worker State")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let total = max(reading + writing + waiting, 1)
                HStack(spacing: 2) {
                    if reading > 0 {
                        workerSegment(
                            label: "Read",
                            count: reading,
                            fraction: CGFloat(reading) / CGFloat(total),
                            color: Theme.memory,
                            width: geo.size.width
                        )
                    }
                    if writing > 0 {
                        workerSegment(
                            label: "Write",
                            count: writing,
                            fraction: CGFloat(writing) / CGFloat(total),
                            color: Theme.warning,
                            width: geo.size.width
                        )
                    }
                    if waiting > 0 {
                        workerSegment(
                            label: "Wait",
                            count: waiting,
                            fraction: CGFloat(waiting) / CGFloat(total),
                            color: Theme.disk,
                            width: geo.size.width
                        )
                    }
                }
            }
            .frame(height: 28)
            .clipShape(.rect(cornerRadius: 6))

            HStack(spacing: 16) {
                legendDot("Reading", color: Theme.memory)
                legendDot("Writing", color: Theme.warning)
                legendDot("Waiting", color: Theme.disk)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .cardStyle(cornerRadius: 12)
    }

    private func workerSegment(label: String, count: Int64, fraction: CGFloat, color: Color, width: CGFloat) -> some View {
        color.opacity(0.7)
            .frame(width: max(fraction * width - 2, 4))
            .overlay {
                if fraction > 0.15 {
                    Text("\(count)")
                        .font(.caption2.monospacedDigit().weight(.medium))
                        .foregroundStyle(.white)
                }
            }
    }

    private func legendDot(_ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
        }
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, value: String, warn: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.monospacedDigit().weight(.medium))
                .foregroundStyle(warn ? Theme.warning : .primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func formatLargeNumber(_ n: Int64) -> String {
        if n >= 1_000_000_000 {
            return String(format: "%.1fB", Double(n) / 1_000_000_000)
        } else if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }
}
