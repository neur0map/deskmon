import SwiftUI

struct DashboardView: View {
    @Environment(ServerManager.self) private var serverManager
    @State private var showingAddServer = false
    @State private var showingSettings = false
    @State private var editingServer: ServerInfo?
    @State private var selectedContainer: DockerContainer?
    @State private var selectedProcess: ProcessInfo?

    @State private var isRestartingAgent = false
    @State private var restartFeedback: String?

    // Inline edit form state
    @State private var editName = ""
    @State private var editHost = ""
    @State private var editPort = ""
    @State private var editToken = ""
    @State private var editTesting = false
    @State private var editError: String?

    var body: some View {
        @Bindable var manager = serverManager

        VStack(spacing: 0) {
            if let container = liveSelectedContainer {
                containerDetailPanel(container: container)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else if let process = liveSelectedProcess {
                processDetailPanel(process: process)
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
                            NetworkStatsView(network: stats.network, history: server.networkHistory)
                        }

                        if !server.containers.isEmpty {
                            ContainerListView(containers: server.containers) { container in
                                withAnimation(.smooth(duration: 0.3)) {
                                    selectedProcess = nil
                                    selectedContainer = container
                                }
                            }
                        }

                        if !server.processes.isEmpty {
                            ProcessListView(
                                processes: server.processes,
                                onSelect: { process in
                                    withAnimation(.smooth(duration: 0.3)) {
                                        selectedContainer = nil
                                        selectedProcess = process
                                    }
                                }
                            )
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
                VStack(alignment: .leading, spacing: 18) {
                    // --- Servers ---
                    settingsSectionHeader("Servers")

                    VStack(spacing: 0) {
                        ForEach(Array(serverManager.servers.enumerated()), id: \.element.id) { index, server in
                            serverSettingsRow(server)
                            if index < serverManager.servers.count - 1 {
                                Divider().padding(.leading, 28)
                            }
                        }

                        if !serverManager.servers.isEmpty {
                            Divider().padding(.leading, 12)
                        }

                        Button { showingAddServer = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Theme.accent)
                                Text("Add Server")
                            }
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                    .cardStyle(cornerRadius: 10)

                    // --- Agent ---
                    settingsSectionHeader("Agent")

                    VStack(spacing: 0) {
                        groupedRow {
                            Toggle("Polling", isOn: Binding(
                                get: { serverManager.isPolling },
                                set: { newValue in
                                    if newValue { serverManager.startPolling() }
                                    else { serverManager.stopPolling() }
                                }
                            ))
                            .toggleStyle(.switch)
                            .tint(Theme.accent)
                        }

                        Divider().padding(.leading, 12)

                        groupedRow {
                            @Bindable var manager = serverManager
                            Picker("Refresh", selection: $manager.pollingInterval) {
                                ForEach(ServerManager.intervalOptions, id: \.value) { option in
                                    Text(option.label).tag(option.value)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.secondary)
                        }

                        Divider().padding(.leading, 12)

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
                            HStack {
                                Text("Restart Agent")
                                Spacer()
                                if isRestartingAgent {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRestartingAgent)

                        if let restartFeedback {
                            Text(restartFeedback)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 4)
                        }
                    }
                    .cardStyle(cornerRadius: 10)

                    // --- About ---
                    settingsSectionHeader("About")

                    VStack(spacing: 0) {
                        groupedRow {
                            HStack {
                                Text("Version")
                                Spacer()
                                Text("1.0.0")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider().padding(.leading, 12)

                        groupedRow {
                            HStack {
                                Text("App")
                                Spacer()
                                Text("Deskmon")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .cardStyle(cornerRadius: 10)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
    }

    private func settingsSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    @ViewBuilder
    private func groupedRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }

    // MARK: - Inline Edit Panel

    private var editNeedsReVerify: Bool {
        guard let server = editingServer else { return true }
        return editHost != server.host ||
               editPort != String(server.port) ||
               editToken != server.token
    }

    private var editIsValid: Bool {
        !editName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !editHost.trimmingCharacters(in: .whitespaces).isEmpty &&
        !editToken.trimmingCharacters(in: .whitespaces).isEmpty
    }

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

                Button {
                    Task { await testAndSaveEdit(server: server) }
                } label: {
                    if editTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .disabled(!editIsValid || editTesting)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    editField("Name", text: $editName, prompt: "Homelab")
                    editField("Host / IP", text: $editHost, prompt: "192.168.1.100")

                    HStack(spacing: 12) {
                        editField("Port", text: $editPort, prompt: "7654")
                            .frame(width: 100)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Token")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            SecureField("", text: $editToken, prompt: Text("Agent token").foregroundStyle(.quaternary))
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    if let editError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.critical)
                            Text(editError)
                                .foregroundStyle(Theme.critical)
                        }
                        .font(.caption)
                    }
                }
                .padding(12)
            }
        }
    }

    private func testAndSaveEdit(server: ServerInfo) async {
        editError = nil

        let trimmedHost = editHost.trimmingCharacters(in: .whitespaces)
        let trimmedToken = editToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let portNum = Int(editPort) ?? 7654

        if editNeedsReVerify {
            editTesting = true
            defer { editTesting = false }

            let result = await serverManager.testConnection(
                host: trimmedHost, port: portNum, token: trimmedToken
            )

            switch result {
            case .success:
                break
            case .unreachable:
                editError = "Server unreachable at \(trimmedHost):\(portNum)"
                return
            case .unauthorized:
                editError = "Invalid token"
                return
            case .error(let msg):
                editError = msg
                return
            }
        }

        serverManager.updateServer(
            id: server.id,
            name: editName.trimmingCharacters(in: .whitespaces),
            host: trimmedHost,
            port: portNum,
            token: trimmedToken
        )
        withAnimation(.smooth(duration: 0.3)) {
            editingServer = nil
        }
    }

    // MARK: - Container Detail Panel

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

    private func processDetailPanel(process: ProcessInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation(.smooth(duration: 0.3)) {
                        selectedProcess = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text(process.name)
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

            ProcessDetailView(process: process)
        }
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
        editTesting = false
        editError = nil
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
