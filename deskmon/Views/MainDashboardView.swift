import SwiftUI

struct MainDashboardView: View {
    @Environment(ServerManager.self) private var serverManager
    @State private var showingAddServer = false
    @State private var showingSettings = false
    @State private var editingServer: ServerInfo?
    @State private var selectedContainer: DockerContainer?
    @State private var isRestartingAgent = false
    @State private var restartFeedback: String?

    var body: some View {
        @Bindable var manager = serverManager

        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 0) {
                HStack {
                    Text("Servers")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button { showingAddServer = true } label: {
                        Image(systemName: "plus")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(serverManager.servers) { server in
                            sidebarRow(server: server, isSelected: server.id == serverManager.selectedServerID)
                                .onTapGesture {
                                    withAnimation(.smooth(duration: 0.25)) {
                                        manager.selectedServerID = server.id
                                        selectedContainer = nil
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                }

                Divider().overlay(Theme.cardBorder)

                // Sidebar footer
                HStack(spacing: 8) {
                    Button { showingSettings.toggle() } label: {
                        Image(systemName: "gear")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingSettings) {
                        settingsPopover
                            .frame(width: 320, height: 500)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(width: 220)
            .background(Color.white.opacity(0.04))

            // Detail — OLED black with inner rounded border
            VStack(spacing: 0) {
                if let server = serverManager.selectedServer {
                    detailContent(server: server)
                        .animation(.smooth, value: serverManager.selectedServerID)
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.cardBorder)
                        Text("Select a Server")
                            .font(.headline)
                        Text("Choose a server from the sidebar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .innerPanel()
            .padding(6)

            // Container Detail Panel
            if let container = liveSelectedContainer {
                VStack(spacing: 0) {
                    HStack {
                        Text("Container")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            withAnimation(.smooth(duration: 0.25)) {
                                selectedContainer = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .contentShape(.rect)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider().overlay(Theme.cardBorder)

                    ContainerDetailView(container: container)
                }
                .frame(width: 240)
                .background(Color.white.opacity(0.04))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddServer) {
            AddServerSheet()
        }
        .sheet(item: $editingServer) { server in
            EditServerSheet(server: server)
        }
        .onAppear {
            NSApp.setActivationPolicy(.regular)
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Sidebar Row

    private func sidebarRow(server: ServerInfo, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(server.status.color)
                .frame(width: 10, height: 10)
                .animation(.smooth, value: server.status)

            VStack(alignment: .leading, spacing: 3) {
                Text(server.name)
                    .font(.body.weight(.medium))

                if let stats = server.stats {
                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Image(systemName: "cpu")
                                .foregroundStyle(Theme.cpu)
                            Text(String(format: "%.0f%%", stats.cpu.usagePercent))
                                .contentTransition(.numericText())
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "memorychip")
                                .foregroundStyle(Theme.memory)
                            Text(String(format: "%.0f%%", stats.memory.usagePercent))
                                .contentTransition(.numericText())
                        }
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                } else {
                    Text(server.host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Theme.accent.opacity(0.15) : .clear, in: .rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Theme.accent.opacity(0.3) : .clear, lineWidth: 1)
        )
    }

    // MARK: - Detail

    private var liveSelectedContainer: DockerContainer? {
        guard let id = selectedContainer?.id,
              let server = serverManager.selectedServer else { return nil }
        return server.containers.first { $0.id == id }
    }

    @ViewBuilder
    private func detailContent(server: ServerInfo) -> some View {
        if let stats = server.stats {
            ScrollView {
                VStack(spacing: 16) {
                    statusBar(server: server, stats: stats)

                    HStack(spacing: 12) {
                        GaugeCardView(
                            title: "CPU",
                            value: String(format: "%.1f%%", stats.cpu.usagePercent),
                            percent: stats.cpu.usagePercent,
                            icon: "cpu",
                            subtitle: "\(stats.cpu.coreCount) cores",
                            tint: Theme.cpu,
                            tintLight: Theme.cpuLight
                        )
                        GaugeCardView(
                            title: "Memory",
                            value: String(format: "%.1f%%", stats.memory.usagePercent),
                            percent: stats.memory.usagePercent,
                            icon: "memorychip",
                            subtitle: "\(ByteFormatter.format(stats.memory.usedBytes)) / \(ByteFormatter.format(stats.memory.totalBytes))",
                            tint: Theme.memory,
                            tintLight: Theme.memoryLight
                        )
                        GaugeCardView(
                            title: "Disk",
                            value: String(format: "%.1f%%", stats.disk.usagePercent),
                            percent: stats.disk.usagePercent,
                            icon: "internaldrive",
                            subtitle: "\(ByteFormatter.format(stats.disk.usedBytes)) / \(ByteFormatter.format(stats.disk.totalBytes))",
                            tint: Theme.disk,
                            tintLight: Theme.diskLight
                        )
                    }

                    networkCard(stats: stats, history: server.networkHistory)

                    if !server.containers.isEmpty {
                        ContainerTableView(
                            containers: server.containers,
                            selectedID: selectedContainer?.id,
                            onSelect: { container in
                                withAnimation(.smooth(duration: 0.25)) {
                                    if selectedContainer?.id == container.id {
                                        selectedContainer = nil
                                    } else {
                                        selectedContainer = container
                                    }
                                }
                            }
                        )
                    }

                    if !server.processes.isEmpty {
                        ProcessListView(processes: server.processes)
                    }
                }
                .padding(20)
            }
        } else {
            ProgressView("Connecting...")
        }
    }

    // MARK: - Status Bar

    private func statusBar(server: ServerInfo, stats: ServerStats) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(server.status.color)
                    .frame(width: 10, height: 10)
                    .animation(.smooth, value: server.status)
                Text(server.status.label)
                    .font(.subheadline.weight(.medium))
            }

            Divider().frame(height: 16).overlay(Theme.cardBorder)

            Label("\(server.host):\(server.port)", systemImage: "network")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Divider().frame(height: 16).overlay(Theme.cardBorder)

            Label("Up \(ByteFormatter.formatUptime(stats.uptimeSeconds))", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider().frame(height: 16).overlay(Theme.cardBorder)

            Label(String(format: "%.0f\u{00B0}C", stats.cpu.temperature), systemImage: "thermometer.medium")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .tintedCardStyle(cornerRadius: 12, tint: server.status.color)
    }

    // MARK: - Network

    private func networkCard(stats: ServerStats, history: [NetworkSample]) -> some View {
        NetworkStatsView(network: stats.network, history: history)
    }

    // MARK: - Settings Popover

    private var settingsPopover: some View {
        @Bindable var manager = serverManager

        return VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            SectionHeaderView(title: "Servers", count: serverManager.servers.count)

            VStack(spacing: 4) {
                ForEach(serverManager.servers) { server in
                    serverPopoverRow(server)
                }
            }

            Button {
                showingSettings = false
                showingAddServer = true
            } label: {
                Label("Add Server", systemImage: "plus")
                    .font(.callout)
            }
            .buttonStyle(.dark)

            Divider().overlay(Theme.cardBorder)

            SectionHeaderView(title: "Agent")

            VStack(spacing: 10) {
                Toggle("Polling", isOn: Binding(
                    get: { serverManager.isPolling },
                    set: { newValue in
                        if newValue { serverManager.startPolling() }
                        else { serverManager.stopPolling() }
                    }
                ))
                .toggleStyle(.switch)
                .tint(Theme.accent)
                .font(.callout)

                Picker("Refresh Interval", selection: $manager.pollingInterval) {
                    ForEach(ServerManager.intervalOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .pickerStyle(.menu)
                .font(.callout)

                HStack(spacing: 8) {
                    Button {
                        isRestartingAgent = true
                        restartFeedback = nil
                        Task {
                            do {
                                let msg = try await serverManager.restartAgent()
                                restartFeedback = msg.capitalized
                            } catch {
                                restartFeedback = error.localizedDescription
                            }
                            isRestartingAgent = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if isRestartingAgent {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Label("Restart Agent", systemImage: "arrow.clockwise")
                                .font(.callout)
                        }
                    }
                    .disabled(isRestartingAgent)

                    Spacer()

                    if let restartFeedback {
                        Text(restartFeedback)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)

            Divider().overlay(Theme.cardBorder)

            SectionHeaderView(title: "General")

            VStack(spacing: 2) {
                settingsPopoverRow("Version", value: "1.0.0")
            }
        }
        .padding(16)
    }

    private func serverPopoverRow(_ server: ServerInfo) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(server.status.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(server.name)
                    .font(.callout.weight(.medium))
                Text("\(server.host):\(server.port)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                showingSettings = false
                editingServer = server
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.smooth) {
                    serverManager.deleteServer(server)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(Theme.critical.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .cardStyle(cornerRadius: 8)
    }

    private func settingsPopoverRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            Text(value).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
