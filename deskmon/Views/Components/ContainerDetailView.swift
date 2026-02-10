import SwiftUI

struct ContainerDetailView: View {
    let container: DockerContainer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerSection
                if container.status == .running {
                    cpuSection
                    memorySection
                    networkSection
                    diskIOSection
                }
            }
            .padding(16)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(container.status.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(container.name)
                    .font(.headline)
                Text(container.status.label)
                    .font(.caption)
                    .foregroundStyle(container.status.color)
            }

            Spacer()

            if let uptime = container.uptime {
                Label(uptime, systemImage: "clock")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .tintedCardStyle(cornerRadius: 10, tint: container.status.color)
    }

    // MARK: - CPU

    private var cpuSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("CPU", systemImage: "cpu")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f%%", container.cpuPercent))
                    .font(.callout.monospacedDigit().weight(.medium))
                    .contentTransition(.numericText())
            }

            ProgressBarView(value: container.cpuPercent, tint: Theme.cpu, tintLight: Theme.cpuLight)

            HStack {
                Label("\(container.pids) PIDs", systemImage: "list.number")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
    }

    // MARK: - Memory

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f / %.0f MB", container.memoryUsageMB, container.memoryLimitMB))
                    .font(.callout.monospacedDigit().weight(.medium))
                    .contentTransition(.numericText())
            }

            ProgressBarView(value: container.memoryPercent, tint: Theme.memory, tintLight: Theme.memoryLight)

            HStack {
                Text(String(format: "%.1f%%", container.memoryPercent))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
    }

    // MARK: - Network

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Network", systemImage: "network")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Theme.download)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Received")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(ByteFormatter.format(container.networkRxBytes))
                            .font(.callout.monospacedDigit().weight(.medium))
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(Theme.upload)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Sent")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(ByteFormatter.format(container.networkTxBytes))
                            .font(.callout.monospacedDigit().weight(.medium))
                    }
                }
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
    }

    // MARK: - Disk I/O

    private var diskIOSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Disk I/O", systemImage: "internaldrive")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.to.line")
                        .foregroundStyle(Theme.disk)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Read")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(ByteFormatter.format(container.blockReadBytes))
                            .font(.callout.monospacedDigit().weight(.medium))
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.to.line")
                        .foregroundStyle(Theme.diskLight)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Written")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(ByteFormatter.format(container.blockWriteBytes))
                            .font(.callout.monospacedDigit().weight(.medium))
                    }
                }
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
    }

    // TODO: Port mappings section — show host:container/protocol table
    // TODO: Health check section — status badge + last check output
    // TODO: Container actions bar — Start/Stop/Restart buttons (requires agent POST endpoints)
}
