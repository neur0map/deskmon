import SwiftUI

struct MainDashboardView: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(AppLockManager.self) private var lockManager
    @State private var showingAddServer = false
    @State private var editingServer: ServerInfo?
    @State private var selectedContainer: DockerContainer?
    @State private var selectedProcess: ProcessInfo?
    @State private var isRestartingAgent = false
    @State private var restartFeedback: String?
    @State private var inspectorIdealWidth: Double = 280
    @State private var inspectorMinWidth: Double = 200

    var body: some View {
        ZStack {
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
                                        serverManager.selectedServerID = server.id
                                        selectedContainer = nil
                                        selectedProcess = nil
                                    }
                                }
                                .contextMenu {
                                    Button("Edit...") { editingServer = server }
                                    Button("Delete", role: .destructive) {
                                        withAnimation(.smooth) {
                                            serverManager.deleteServer(server)
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                }

                Divider().overlay(Theme.cardBorder)

                // Sidebar footer — agent status + actions
                agentFooter
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
            .inspector(isPresented: Binding(
                get: { liveSelectedContainer != nil || liveSelectedProcess != nil },
                set: { if !$0 { withAnimation(.smooth(duration: 0.25)) { selectedContainer = nil; selectedProcess = nil } } }
            )) {
                inspectorContent
            }
        }
        .background(Theme.background)

            if lockManager.isLocked(.window) {
                AppLockView(surface: .window)
            }
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddServer) {
            AddServerSheet()
        }
        .sheet(item: $editingServer) { server in
            EditServerSheet(server: server)
        }
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            let v = UserDefaults.standard.double(forKey: "inspectorWidth")
            if v >= 200 { inspectorIdealWidth = v }
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
            lockManager.lock(.window)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            lockManager.lockAllSurfaces()
            serverManager.startStreaming()
        }
    }

    private func pinInspectorWidth() {
        inspectorMinWidth = inspectorIdealWidth
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            inspectorMinWidth = 200
        }
    }

    // MARK: - Agent Footer

    private var agentFooter: some View {
        VStack(spacing: 8) {
            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(serverManager.isConnected ? Theme.healthy : Theme.warning)
                    .frame(width: 7, height: 7)
                    .animation(.smooth, value: serverManager.isConnected)

                Text(serverManager.isConnected ? "Connected" : "Reconnecting...")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let restartFeedback {
                    Text(restartFeedback)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .transition(.opacity)
                }
            }

            // Action buttons
            HStack(spacing: 6) {
                Button {
                    serverManager.stopStreaming()
                    serverManager.startStreaming()
                } label: {
                    Label("Reconnect", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    isRestartingAgent = true
                    restartFeedback = nil
                    Task {
                        do {
                            let msg = try await serverManager.restartAgent()
                            withAnimation { restartFeedback = msg.capitalized }
                        } catch {
                            withAnimation { restartFeedback = error.localizedDescription }
                        }
                        isRestartingAgent = false
                        // Clear feedback after a few seconds
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation { restartFeedback = nil }
                    }
                } label: {
                    HStack(spacing: 3) {
                        if isRestartingAgent {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        Label("Restart Agent", systemImage: "arrow.clockwise")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(isRestartingAgent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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

    private var liveSelectedProcess: ProcessInfo? {
        guard let selected = selectedProcess,
              let server = serverManager.selectedServer else { return nil }
        return server.processes.first { $0.pid == selected.pid } ?? selected
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if let container = liveSelectedContainer {
            ContainerDetailView(container: container)
                .inspectorColumnWidth(min: inspectorMinWidth, ideal: inspectorIdealWidth, max: 560)
                .navigationTitle("Container")
                .background(inspectorWidthSensor)
        } else if let process = liveSelectedProcess {
            ProcessDetailView(process: process)
                .inspectorColumnWidth(min: inspectorMinWidth, ideal: inspectorIdealWidth, max: 560)
                .navigationTitle("Process")
                .background(inspectorWidthSensor)
        }
    }

    private var inspectorWidthSensor: some View {
        GeometryReader { geo in
            Color.clear
                .task(id: geo.size.width) {
                    let w = geo.size.width
                    guard w > 200 && w < 560 else { return }
                    do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                    guard w != inspectorIdealWidth else { return }
                    inspectorIdealWidth = w
                    UserDefaults.standard.set(Double(w), forKey: "inspectorWidth")
                }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func detailContent(server: ServerInfo) -> some View {
        if server.connectionPhase == .live, let stats = server.stats {
            ScrollView {
                VStack(spacing: 16) {
                    statusBar(server: server, stats: stats)

                    SystemMetricsCard(stats: stats)

                    networkCard(stats: stats, history: server.networkHistory)

                    SecurityPanelView(serverID: server.id)

                    if !server.containers.isEmpty {
                        ContainerTableView(
                            containers: server.containers,
                            selectedID: selectedContainer?.id,
                            onSelect: { container in
                                if selectedContainer == nil { pinInspectorWidth() }
                                withAnimation(.smooth(duration: 0.25)) {
                                    selectedProcess = nil
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
                        ProcessListView(
                            processes: server.processes,
                            selectedPID: selectedProcess?.pid,
                            onSelect: { process in
                                if selectedProcess == nil { pinInspectorWidth() }
                                withAnimation(.smooth(duration: 0.25)) {
                                    selectedContainer = nil
                                    if selectedProcess?.pid == process.pid {
                                        selectedProcess = nil
                                    } else {
                                        selectedProcess = process
                                    }
                                }
                            }
                        )
                    }

                    BookmarksSection()
                }
                .padding(20)
            }
        } else if server.connectionPhase == .syncing {
            GoingLiveView()
        } else if server.connectionPhase == .disconnected && server.hasConnectedOnce {
            VStack(spacing: 14) {
                Image(systemName: "bolt.horizontal.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.critical)
                    .symbolEffect(.pulse, options: .repeating)
                Text("Connection Lost")
                    .font(.title3.weight(.semibold))
                Text("Reconnecting to \(server.name)...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 2)
            }
        } else {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Connecting...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
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

            Label("\(server.username)@\(server.host)", systemImage: "network")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Divider().frame(height: 16).overlay(Theme.cardBorder)

            Label("Up \(ByteFormatter.formatUptime(stats.uptimeSeconds))", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if stats.cpu.temperatureAvailable {
                Divider().frame(height: 16).overlay(Theme.cardBorder)

                Label(String(format: "%.0f\u{00B0}C", stats.cpu.temperature), systemImage: "thermometer.medium")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()
        }
        .colorScheme(.dark)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .tintedCardStyle(cornerRadius: 12, tint: server.status.color)
    }

    // MARK: - Network

    private func networkCard(stats: ServerStats, history: [NetworkSample]) -> some View {
        NetworkStatsView(network: stats.network, history: history)
    }
}

