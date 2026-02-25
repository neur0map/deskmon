import SwiftUI

struct N8nDetailView: View {
    let context: PluginContext

    @Environment(ServerManager.self) private var serverManager

    // API key setup
    @State private var savedAPIKey: String?
    @State private var apiKeyInput = ""
    @State private var isSavingKey = false
    @State private var keySetupError: String?

    // Connection
    @State private var client: N8nClient?
    @State private var tunnelError: String?

    // Data
    @State private var workflows: [N8nWorkflow] = []
    @State private var executions: [N8nExecution] = []
    @State private var isLoading = false
    @State private var loadError: String?

    // Trigger
    @State private var selectedTriggerID: String?
    @State private var webhookInfo: (path: String, method: String)?
    @State private var isLoadingWebhookInfo = false
    @State private var isTriggering = false
    @State private var triggerMessage: String?
    @State private var showingTriggerInfo = false

    private let n8nPort = 5678

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if savedAPIKey == nil {
                setupSection
            } else if let error = tunnelError {
                errorSection(error)
            } else if let c = client {
                dataSection(c)
            } else {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connecting to n8n…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .cardStyle(cornerRadius: 10)
                .padding(.vertical, 2)
            }
        }
        .task {
            await initialize()
        }
    }

    // MARK: - Setup

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("n8n", systemImage: "bolt.horizontal.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Enter your n8n API key to view workflow status.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("API Key")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                SecureField("", text: $apiKeyInput, prompt: Text("n8n_api_…").foregroundStyle(.quaternary))
                    .textFieldStyle(.roundedBorder)
            }

            if let error = keySetupError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(Theme.critical)
            }

            HStack {
                Spacer()
                Button {
                    Task { await saveAPIKey() }
                } label: {
                    if isSavingKey {
                        ProgressView().controlSize(.small).padding(.horizontal, 8)
                    } else {
                        Text("Connect")
                    }
                }
                .buttonStyle(.darkProminent)
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty || isSavingKey)
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
    }

    // MARK: - Error

    private func errorSection(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
    }

    // MARK: - Data

    @ViewBuilder
    private func dataSection(_ c: N8nClient) -> some View {
        workflowsSection
        triggerSection(c)
        executionsSection
    }

    private var workflowsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Workflows", systemImage: "bolt.horizontal.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.mini)
                } else {
                    Button {
                        if let c = client { Task { await loadData(with: c) } }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = loadError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(Theme.critical)
            } else if workflows.isEmpty && !isLoading {
                Text("No workflows found")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                let active = workflows.filter(\.active)
                Text("\(active.count) active / \(workflows.count) total")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    ForEach(workflows.prefix(6)) { wf in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(wf.active ? Theme.healthy : Color.secondary.opacity(0.4))
                                .frame(width: 6, height: 6)
                            Text(wf.name)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Text(wf.active ? "active" : "inactive")
                                .font(.caption2)
                                .foregroundStyle(wf.active ? Theme.healthy : Color.secondary.opacity(0.5))
                        }
                    }
                    if workflows.count > 6 {
                        Text("+ \(workflows.count - 6) more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
    }

    // Fallback name lookup for executions whose workflowData is nil.
    private var workflowNameByID: [String: String] {
        Dictionary(uniqueKeysWithValues: workflows.map { ($0.id, $0.name) })
    }

    private var executionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Recent Executions", systemImage: "clock.arrow.2.circlepath")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.mini)
                } else {
                    Button {
                        if let c = client { Task { await loadData(with: c) } }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if executions.isEmpty && !isLoading {
                Text("No recent executions")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 6) {
                    ForEach(executions.prefix(8)) { exec in
                        let name = exec.workflowData?.name
                            ?? workflowNameByID[exec.workflowId ?? ""]
                            ?? exec.workflowId
                            ?? "Unknown"
                        HStack(spacing: 6) {
                            Image(systemName: exec.statusIcon)
                                .font(.caption2)
                                .foregroundStyle(exec.statusColor)
                                .frame(width: 14, alignment: .center)
                            Text(name)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 4)
                            Text("#\(exec.id) · \(exec.formattedStartTime)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .fixedSize()
                        }
                    }
                }
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
    }

    private func triggerSection(_ c: N8nClient) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Label("Trigger Workflow", systemImage: "play.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Button {
                    showingTriggerInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingTriggerInfo, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Webhook Requirements", systemImage: "info.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("For a workflow to be triggerable from here, it must have a **Webhook** trigger node configured with:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            requirementRow("HTTP Method set to **POST**")
                            requirementRow("Authentication set to **None**")
                            requirementRow("The workflow must be **active**")
                        }
                    }
                    .padding(14)
                    .frame(width: 260)
                    .preferredColorScheme(.dark)
                }
            }

            if workflows.isEmpty {
                Text("No workflows available")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 8) {
                    Picker("", selection: $selectedTriggerID) {
                        Text("Select a workflow…").tag(nil as String?)
                        ForEach(workflows) { wf in
                            Text(wf.name).tag(wf.id as String?)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isLoadingWebhookInfo {
                        ProgressView().controlSize(.small)
                    } else {
                        Button {
                            Task { await triggerWorkflow(with: c) }
                        } label: {
                            if isTriggering {
                                ProgressView().controlSize(.small).padding(.horizontal, 4)
                            } else {
                                Text("Run")
                            }
                        }
                        .buttonStyle(.darkProminent)
                        .disabled(webhookInfo == nil || isTriggering)
                        .fixedSize()
                    }
                }

                if selectedTriggerID != nil && !isLoadingWebhookInfo && webhookInfo == nil {
                    Text("This workflow has no Webhook trigger node")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if let msg = triggerMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(msg.hasPrefix("Error") ? Theme.critical : Theme.healthy)
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 10)
        .onChange(of: selectedTriggerID) { _, newID in
            webhookInfo = nil
            triggerMessage = nil
            guard let id = newID else { return }
            Task { await loadWebhookInfo(for: id, client: c) }
        }
    }

    // MARK: - Actions

    private func initialize() async {
        savedAPIKey = KeychainStore.loadN8nAPIKey(serverID: context.serverID)
        guard savedAPIKey != nil else { return }
        await openTunnelAndConnect()
    }

    private func openTunnelAndConnect() async {
        guard let apiKey = savedAPIKey else { return }
        tunnelError = nil
        do {
            let url = try await serverManager.pluginTunnelURL(
                for: context.serverID,
                remotePort: n8nPort
            )
            let c = N8nClient(baseURL: url, apiKey: apiKey)
            client = c
            await loadData(with: c)
        } catch {
            tunnelError = "Cannot reach n8n: \(error.localizedDescription)"
        }
    }

    private func saveAPIKey() async {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSavingKey = true
        keySetupError = nil
        defer { isSavingKey = false }

        do {
            let url = try await serverManager.pluginTunnelURL(
                for: context.serverID,
                remotePort: n8nPort
            )
            let tempClient = N8nClient(baseURL: url, apiKey: trimmed)
            _ = try await tempClient.fetchWorkflows()  // verify key works

            try KeychainStore.saveN8nAPIKey(trimmed, serverID: context.serverID)
            savedAPIKey = trimmed
            client = tempClient
            await loadData(with: tempClient)
        } catch {
            keySetupError = error.localizedDescription
        }
    }

    private func loadData(with c: N8nClient) async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            async let wf = c.fetchWorkflows()
            async let ex = c.fetchExecutions()
            async let running = c.fetchRunningExecutions()
            let (newWorkflows, recent, active) = try await (wf, ex, running)
            workflows = newWorkflows
            // Active executions first, then recent history; deduplicate by ID
            var seen = Set<String>()
            executions = (active + recent).filter { seen.insert($0.id).inserted }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func loadWebhookInfo(for workflowID: String, client c: N8nClient) async {
        isLoadingWebhookInfo = true
        defer { isLoadingWebhookInfo = false }
        webhookInfo = try? await c.fetchWebhookInfo(workflowID: workflowID)
    }

    private func triggerWorkflow(with c: N8nClient) async {
        guard let info = webhookInfo else { return }

        isTriggering = true
        triggerMessage = nil
        defer { isTriggering = false }

        do {
            try await c.triggerWebhook(path: info.path, method: info.method)
            triggerMessage = "Triggered successfully"
            try? await Task.sleep(for: .seconds(1))
            await loadData(with: c)
        } catch {
            triggerMessage = "Error: \(error.localizedDescription)"
        }
    }

    private func requirementRow(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.healthy)
                .frame(width: 12)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - N8nExecution status helpers

private extension N8nExecution {
    var statusIcon: String {
        switch status {
        case "success": "checkmark.circle.fill"
        case "error", "crashed": "xmark.circle.fill"
        case "running": "arrow.triangle.2.circlepath"
        case "waiting": "clock.fill"
        default: "circle"
        }
    }

    var statusColor: Color {
        switch status {
        case "success": Theme.healthy
        case "error", "crashed": Theme.critical
        case "running": Theme.accent
        case "waiting": Theme.warning
        default: .secondary
        }
    }
}
