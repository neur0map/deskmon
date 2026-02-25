import SwiftUI

struct ContainerDetailView: View {
    let container: DockerContainer

    @Environment(ServerManager.self) private var serverManager
    @State private var actionInProgress: ContainerAction?
    @State private var showStopConfirmation = false
    @State private var showRestartConfirmation = false
    @State private var actionError: String?
    @State private var showingLogs = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerSection
                actionsSection
                if container.status == .running {
                    cpuSection
                    memorySection
                    portMappingsSection
                    networkSection
                    diskIOSection
                }
                if container.status == .running,
                   let plugin = PluginRegistry.shared.plugin(for: container.image),
                   let serverID = serverManager.selectedServerID {
                    plugin.makeDetailView(
                        context: PluginContext(serverID: serverID, container: container)
                    )
                }
            }
            .padding(16)
        }
        .alert("Stop Container?", isPresented: $showStopConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Stop", role: .destructive) { performAction(.stop) }
        } message: {
            Text("This will stop \(container.name).")
        }
        .alert("Restart Container?", isPresented: $showRestartConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restart", role: .destructive) { performAction(.restart) }
        } message: {
            Text("This will restart \(container.name).")
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
                HStack(spacing: 6) {
                    Text(container.status.label)
                        .font(.caption)
                        .foregroundStyle(container.status.color)

                    if container.healthStatus != .none {
                        Label(container.healthStatus.label, systemImage: container.healthStatus.systemImage)
                            .font(.caption2)
                            .foregroundStyle(container.healthStatus.color)
                    }

                    if container.restartCount > 0 {
                        Label("\(container.restartCount)", systemImage: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
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

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if container.status == .stopped {
                    actionButton("Start", systemImage: "play.fill", color: Theme.healthy, action: .start) {
                        performAction(.start)
                    }
                }
                if container.status == .running {
                    actionButton("Stop", systemImage: "stop.fill", color: Theme.critical, action: .stop) {
                        showStopConfirmation = true
                    }
                    actionButton("Restart", systemImage: "arrow.clockwise", color: Theme.warning, action: .restart) {
                        showRestartConfirmation = true
                    }
                }

                Spacer()

                Button { showingLogs = true } label: {
                    Label("Logs", systemImage: "doc.text")
                }
                .buttonStyle(.dark)
                .font(.caption.weight(.medium))
            }

            if let actionError {
                Text(actionError)
                    .font(.caption2)
                    .foregroundStyle(Theme.critical)
            }
        }
        .padding(12)
        .tintedCardStyle(cornerRadius: 10, tint: Theme.accent)
        .sheet(isPresented: $showingLogs) {
            ContainerLogView(container: container)
        }
    }

    private func actionButton(_ label: String, systemImage: String, color: Color, action: ContainerAction, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if actionInProgress == action {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                }
                Text(label)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(actionInProgress != nil)
    }

    private func performAction(_ action: ContainerAction) {
        actionError = nil
        actionInProgress = action
        Task {
            do {
                _ = try await serverManager.performContainerAction(
                    containerID: container.id,
                    action: action
                )
            } catch {
                actionError = error.localizedDescription
            }
            actionInProgress = nil
        }
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

    // MARK: - Port Mappings

    @ViewBuilder
    private var portMappingsSection: some View {
        if !container.ports.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Ports", systemImage: "network.badge.shield.half.filled")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    ForEach(container.ports) { port in
                        HStack {
                            Text("\(port.hostPort)")
                                .font(.callout.monospacedDigit().weight(.medium))
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("\(port.containerPort)/\(port.protocol)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            .padding(12)
            .cardStyle(cornerRadius: 10)
        }
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
}
