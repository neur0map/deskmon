import SwiftUI

struct DashboardView: View {
    @Environment(ServerManager.self) private var serverManager
    @State private var showingAddServer = false
    @State private var showingSettings = false
    @State private var editingServer: ServerInfo?
    @State private var selectedContainer: DockerContainer?

    // Inline edit form state
    @State private var editName = ""
    @State private var editHost = ""
    @State private var editPort = ""
    @State private var editToken = ""

    var body: some View {
        @Bindable var manager = serverManager

        VStack(spacing: 0) {
            if let container = liveSelectedContainer {
                containerDetailPanel(container: container)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else if let server = editingServer {
                inlineEditPanel(server: server)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else if showingSettings {
                settingsPanel
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else {
                dashboardContent(manager: manager)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .clipped()
        .frame(width: 380, height: 580)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddServer) {
            AddServerSheet()
        }
    }

    // MARK: - Dashboard Content

    private func dashboardContent(manager: ServerManager) -> some View {
        @Bindable var mgr = manager

        return VStack(spacing: 0) {
            if serverManager.servers.count > 1 {
                Picker("Server", selection: $mgr.selectedServerID) {
                    ForEach(serverManager.servers) { server in
                        Text(server.name).tag(server.id as UUID?)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }

            if let server = serverManager.selectedServer {
                ScrollView {
                    VStack(spacing: 10) {
                        ServerHeaderView(server: server)

                        if let stats = server.stats {
                            SystemStatsView(stats: stats)
                            NetworkStatsView(network: stats.network)
                        }

                        if !server.containers.isEmpty {
                            ContainerListView(containers: server.containers) { container in
                                withAnimation(.smooth(duration: 0.3)) {
                                    selectedContainer = container
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .animation(.smooth, value: serverManager.selectedServerID)

                FooterView(
                    onAddServer: { showingAddServer = true },
                    onSettings: {
                        withAnimation(.smooth(duration: 0.3)) {
                            showingSettings = true
                        }
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else {
                Spacer()
                EmptyStateView()
                Spacer()
                FooterView(
                    onAddServer: { showingAddServer = true },
                    onSettings: {
                        withAnimation(.smooth(duration: 0.3)) {
                            showingSettings = true
                        }
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation(.smooth(duration: 0.3)) {
                        showingSettings = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Settings")
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .hidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeaderView(title: "Servers", count: serverManager.servers.count)

                    VStack(spacing: 4) {
                        ForEach(serverManager.servers) { server in
                            serverSettingsRow(server)
                        }
                    }

                    Button { showingAddServer = true } label: {
                        Label("Add Server", systemImage: "plus")
                            .font(.callout)
                    }
                    .buttonStyle(.dark)

                    Divider()

                    SectionHeaderView(title: "Agent")

                    agentControls

                    Divider()

                    SectionHeaderView(title: "General")

                    VStack(spacing: 2) {
                        settingsRow("Version", value: "1.0.0")
                    }
                    .padding(.horizontal, 4)

                    Divider()

                    VStack(spacing: 4) {
                        Text("Deskmon")
                            .font(.callout.weight(.medium))
                        Text("Server monitoring for your menu bar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding(12)
            }
        }
    }

    // MARK: - Inline Edit Panel

    private func inlineEditPanel(server: ServerInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation(.smooth(duration: 0.3)) {
                        editingServer = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Settings")
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Edit Server")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    let portNum = Int(editPort) ?? 9090
                    serverManager.updateServer(
                        id: server.id,
                        name: editName.trimmingCharacters(in: .whitespaces),
                        host: editHost.trimmingCharacters(in: .whitespaces),
                        port: portNum,
                        token: editToken
                    )
                    withAnimation(.smooth(duration: 0.3)) {
                        editingServer = nil
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty ||
                          editHost.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    editField("Name", text: $editName, prompt: "Homelab")
                    editField("Host / IP", text: $editHost, prompt: "192.168.1.100")

                    HStack(spacing: 12) {
                        editField("Port", text: $editPort, prompt: "9090")
                            .frame(width: 100)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Token")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            SecureField("", text: $editToken, prompt: Text("Optional").foregroundStyle(.quaternary))
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(12)
            }
        }
    }

    // MARK: - Agent Controls

    private var agentControls: some View {
        @Bindable var manager = serverManager

        return VStack(spacing: 10) {
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
                // TODO: Send POST /restart to the agent when real networking is wired up
                Button {
                    serverManager.stopPolling()
                    serverManager.startPolling()
                } label: {
                    Label("Restart Agent", systemImage: "arrow.clockwise")
                        .font(.callout)
                }
                .buttonStyle(.dark)

                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Container Detail Panel

    private var liveSelectedContainer: DockerContainer? {
        guard let id = selectedContainer?.id,
              let server = serverManager.selectedServer else { return nil }
        return server.containers.first { $0.id == id }
    }

    private func containerDetailPanel(container: DockerContainer) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation(.smooth(duration: 0.3)) {
                        selectedContainer = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text(container.name)
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .hidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            ContainerDetailView(container: container)
        }
    }

    // MARK: - Helpers

    private func beginEditing(_ server: ServerInfo) {
        editName = server.name
        editHost = server.host
        editPort = String(server.port)
        editToken = server.token
        withAnimation(.smooth(duration: 0.3)) {
            editingServer = server
        }
    }

    private func serverSettingsRow(_ server: ServerInfo) -> some View {
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
                beginEditing(server)
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

    private func settingsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.callout)
            Spacer()
            Text(value)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func editField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(.quaternary))
                .textFieldStyle(.roundedBorder)
        }
    }
}
