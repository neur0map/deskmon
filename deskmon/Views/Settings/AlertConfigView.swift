import SwiftUI
import UserNotifications

struct AlertConfigView: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(AlertManager.self) private var alertManager
    @State private var selectedServerID: UUID?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showSlackURL = false
    @State private var showDiscordURL = false
    @State private var showGenericURL = false

    private var selectedServer: ServerInfo? {
        serverManager.servers.first { $0.id == selectedServerID }
    }

    var body: some View {
        VStack(spacing: 0) {
            if notificationStatus == .denied {
                permissionBanner
            }

            if serverManager.servers.isEmpty {
                emptyState
            } else {
                serverPicker
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                if selectedServerID != nil {
                    ScrollView {
                        alertToggles
                            .padding(16)
                    }
                }

                Spacer(minLength: 0)

                testButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .onAppear {
            if selectedServerID == nil {
                selectedServerID = serverManager.servers.first?.id
            }
            checkPermission()
        }
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(Theme.warning)
            Text("Notifications disabled in System Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
        }
        .padding(10)
        .background(Theme.warning.opacity(0.1), in: .rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.warning.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "bell.badge")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("No Servers")
                .font(.subheadline.weight(.medium))
            Text("Add a server to configure alerts")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Server Picker

    private var serverPicker: some View {
        Picker("Server", selection: $selectedServerID) {
            ForEach(serverManager.servers) { server in
                Text(server.name).tag(Optional(server.id))
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Alert Toggles

    private var alertToggles: some View {
        VStack(spacing: 14) {
            if let serverID = selectedServerID {
                let config = alertManager.config(for: serverID)

                // --- System + Container alert rows ---
                VStack(spacing: 0) {
                    alertRow(
                        icon: "cpu",
                        title: "CPU",
                        tint: Theme.cpu,
                        enabled: config.cpuEnabled,
                        threshold: config.cpuThreshold,
                        sustained: config.cpuSustained,
                        unit: "%",
                        thresholdRange: 50...100,
                        sustainedRange: 5...120,
                        onToggle: { v in setConfig(serverID) { $0.cpuEnabled = v } },
                        onThreshold: { v in setConfig(serverID) { $0.cpuThreshold = v } },
                        onSustained: { v in setConfig(serverID) { $0.cpuSustained = v } }
                    )

                    Divider().overlay(Theme.cardBorder)

                    alertRow(
                        icon: "memorychip",
                        title: "Memory",
                        tint: Theme.memory,
                        enabled: config.memoryEnabled,
                        threshold: config.memoryThreshold,
                        sustained: config.memorySustained,
                        unit: "%",
                        thresholdRange: 50...100,
                        sustainedRange: 5...120,
                        onToggle: { v in setConfig(serverID) { $0.memoryEnabled = v } },
                        onThreshold: { v in setConfig(serverID) { $0.memoryThreshold = v } },
                        onSustained: { v in setConfig(serverID) { $0.memorySustained = v } }
                    )

                    Divider().overlay(Theme.cardBorder)

                    alertRow(
                        icon: "internaldrive",
                        title: "Disk",
                        tint: Theme.disk,
                        enabled: config.diskEnabled,
                        threshold: config.diskThreshold,
                        sustained: nil,
                        unit: "%",
                        thresholdRange: 50...100,
                        sustainedRange: nil,
                        onToggle: { v in setConfig(serverID) { $0.diskEnabled = v } },
                        onThreshold: { v in setConfig(serverID) { $0.diskThreshold = v } },
                        onSustained: nil
                    )

                    Divider().overlay(Theme.cardBorder)

                    simpleToggleRow(
                        icon: "shippingbox",
                        title: "Container Down",
                        subtitle: "Alert when a running container stops",
                        tint: Theme.warning,
                        enabled: config.containerDownEnabled,
                        onToggle: { v in setConfig(serverID) { $0.containerDownEnabled = v } }
                    )

                    Divider().overlay(Theme.cardBorder)

                    alertRow(
                        icon: "network",
                        title: "Network Errors",
                        tint: Theme.critical,
                        enabled: config.networkErrorsEnabled,
                        threshold: nil,
                        sustained: config.networkErrorsSustained,
                        unit: nil,
                        thresholdRange: nil,
                        sustainedRange: 5...60,
                        onToggle: { v in setConfig(serverID) { $0.networkErrorsEnabled = v } },
                        onThreshold: nil,
                        onSustained: { v in setConfig(serverID) { $0.networkErrorsSustained = v } }
                    )

                    Divider().overlay(Theme.cardBorder)

                    alertRow(
                        icon: "shippingbox.fill",
                        title: "Container CPU",
                        tint: Theme.cpu,
                        enabled: config.containerCPUEnabled,
                        threshold: config.containerCPUThreshold,
                        sustained: config.containerCPUSustained,
                        unit: "%",
                        thresholdRange: 50...100,
                        sustainedRange: 10...120,
                        onToggle: { v in setConfig(serverID) { $0.containerCPUEnabled = v } },
                        onThreshold: { v in setConfig(serverID) { $0.containerCPUThreshold = v } },
                        onSustained: { v in setConfig(serverID) { $0.containerCPUSustained = v } }
                    )

                    Divider().overlay(Theme.cardBorder)

                    alertRow(
                        icon: "shippingbox.fill",
                        title: "Container Memory",
                        tint: Theme.memory,
                        enabled: config.containerMemoryEnabled,
                        threshold: config.containerMemoryThreshold,
                        sustained: config.containerMemorySustained,
                        unit: "%",
                        thresholdRange: 50...100,
                        sustainedRange: 10...120,
                        onToggle: { v in setConfig(serverID) { $0.containerMemoryEnabled = v } },
                        onThreshold: { v in setConfig(serverID) { $0.containerMemoryThreshold = v } },
                        onSustained: { v in setConfig(serverID) { $0.containerMemorySustained = v } }
                    )

                    Divider().overlay(Theme.cardBorder)

                    simpleToggleRow(
                        icon: "heart.slash",
                        title: "Container Unhealthy",
                        subtitle: "Alert when a container's health check starts failing",
                        tint: Theme.critical,
                        enabled: config.containerUnhealthyEnabled,
                        onToggle: { v in setConfig(serverID) { $0.containerUnhealthyEnabled = v } }
                    )

                    Divider().overlay(Theme.cardBorder)

                    simpleToggleRow(
                        icon: "arrow.clockwise.circle",
                        title: "Container Restart Spike",
                        subtitle: "Alert when a container exceeds \(config.containerRestartThreshold) restarts",
                        tint: Theme.warning,
                        enabled: config.containerRestartSpikeEnabled,
                        onToggle: { v in setConfig(serverID) { $0.containerRestartSpikeEnabled = v } }
                    )

                    Divider().overlay(Theme.cardBorder)

                    simpleToggleRow(
                        icon: "puzzlepiece.extension",
                        title: "Plugin Alerts",
                        subtitle: "Enable alerts defined by container plugins (e.g. n8n execution failures)",
                        tint: Theme.accent,
                        enabled: config.pluginAlertsEnabled,
                        onToggle: { v in setConfig(serverID) { $0.pluginAlertsEnabled = v } }
                    )
                }
                .cardStyle(cornerRadius: 12)

                // --- Slack section ---
                slackSection(serverID: serverID, config: config)

                // --- Discord section ---
                discordSection(serverID: serverID, config: config)

                // --- Generic webhook section ---
                genericWebhookSection(serverID: serverID, config: config)

                // --- Alert history ---
                alertHistorySection
            }
        }
    }

    // MARK: - Slack Section

    private func slackSection(serverID: UUID, config: AlertConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "message.badge.filled.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.healthy)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Slack Notifications")
                        .font(.subheadline.weight(.medium))
                    Text("Send alerts to a Slack channel via Incoming Webhook")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                WebhookInfoButton(
                    title: "Setting up Slack",
                    message: "1. Go to api.slack.com/apps and create a new app.\n2. Under Incoming Webhooks, enable it and click Add New Webhook to Workspace.\n3. Select a channel and copy the Webhook URL."
                )
                Spacer()
                Toggle("", isOn: Binding(
                    get: { config.slackEnabled },
                    set: { v in setConfig(serverID) { $0.slackEnabled = v } }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if config.slackEnabled {
                Divider().overlay(Theme.cardBorder)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Webhook URL")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Group {
                            if showSlackURL {
                                TextField("https://hooks.slack.com/services/...", text: Binding(
                                    get: { config.slackWebhookURL },
                                    set: { v in setConfig(serverID) { $0.slackWebhookURL = v } }
                                ))
                            } else {
                                SecureField("https://hooks.slack.com/services/...", text: Binding(
                                    get: { config.slackWebhookURL },
                                    set: { v in setConfig(serverID) { $0.slackWebhookURL = v } }
                                ))
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())

                        Button {
                            showSlackURL.toggle()
                        } label: {
                            Image(systemName: showSlackURL ? "eye.slash" : "eye")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardStyle(cornerRadius: 12)
        .animation(.smooth(duration: 0.25), value: config.slackEnabled)
    }

    // MARK: - Discord Section

    private func discordSection(serverID: UUID, config: AlertConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "ellipsis.bubble.fill")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.35, green: 0.40, blue: 0.93))
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Discord Notifications")
                        .font(.subheadline.weight(.medium))
                    Text("Send alerts to a Discord channel via Incoming Webhook")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                WebhookInfoButton(
                    title: "Setting up Discord",
                    message: "1. In Discord, right-click a channel and choose Edit Channel.\n2. Go to Integrations → Webhooks → New Webhook.\n3. Name it, optionally set an avatar, and copy the Webhook URL."
                )
                Spacer()
                Toggle("", isOn: Binding(
                    get: { config.discordEnabled },
                    set: { v in setConfig(serverID) { $0.discordEnabled = v } }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if config.discordEnabled {
                Divider().overlay(Theme.cardBorder)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Webhook URL")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Group {
                            if showDiscordURL {
                                TextField("https://discord.com/api/webhooks/...", text: Binding(
                                    get: { config.discordWebhookURL },
                                    set: { v in setConfig(serverID) { $0.discordWebhookURL = v } }
                                ))
                            } else {
                                SecureField("https://discord.com/api/webhooks/...", text: Binding(
                                    get: { config.discordWebhookURL },
                                    set: { v in setConfig(serverID) { $0.discordWebhookURL = v } }
                                ))
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                        Button { showDiscordURL.toggle() } label: {
                            Image(systemName: showDiscordURL ? "eye.slash" : "eye")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardStyle(cornerRadius: 12)
        .animation(.smooth(duration: 0.25), value: config.discordEnabled)
    }

    // MARK: - Generic Webhook Section

    private func genericWebhookSection(serverID: UUID, config: AlertConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generic Webhook")
                        .font(.subheadline.weight(.medium))
                    Text("POST alert data as JSON to any HTTP endpoint")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                WebhookInfoButton(
                    title: "Generic Webhook",
                    message: "deskmon will POST the following JSON to your URL on every alert:\n\n{\n  \"serverName\": \"...\",\n  \"title\": \"...\",\n  \"body\": \"...\",\n  \"timestamp\": \"...\"\n}\n\nCompatible with Zapier, Make, n8n, or any HTTP endpoint."
                )
                Spacer()
                Toggle("", isOn: Binding(
                    get: { config.genericWebhookEnabled },
                    set: { v in setConfig(serverID) { $0.genericWebhookEnabled = v } }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if config.genericWebhookEnabled {
                Divider().overlay(Theme.cardBorder)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Webhook URL")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Group {
                            if showGenericURL {
                                TextField("https://...", text: Binding(
                                    get: { config.genericWebhookURL },
                                    set: { v in setConfig(serverID) { $0.genericWebhookURL = v } }
                                ))
                            } else {
                                SecureField("https://...", text: Binding(
                                    get: { config.genericWebhookURL },
                                    set: { v in setConfig(serverID) { $0.genericWebhookURL = v } }
                                ))
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                        Button { showGenericURL.toggle() } label: {
                            Image(systemName: showGenericURL ? "eye.slash" : "eye")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardStyle(cornerRadius: 12)
        .animation(.smooth(duration: 0.25), value: config.genericWebhookEnabled)
    }

    // MARK: - Alert History

    private var alertHistorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Recent Alerts", systemImage: "bell.badge")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if alertManager.hasUnacknowledgedAlerts {
                    Button("Clear") { alertManager.clearAlerts() }
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().overlay(Theme.cardBorder)

            if alertManager.recentAlerts.isEmpty {
                Text("No alerts fired this session")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                let displayed = Array(alertManager.recentAlerts.prefix(10))
                VStack(spacing: 0) {
                    ForEach(displayed) { alert in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Theme.critical)
                                .frame(width: 6, height: 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(alert.serverName) — \(alert.title)")
                                    .font(.caption.weight(.medium))
                                Text(alert.body)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(alert.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        if alert.id != displayed.last?.id {
                            Divider().overlay(Theme.cardBorder)
                        }
                    }
                }
            }
        }
        .cardStyle(cornerRadius: 12)
    }

    // MARK: - Alert Row

    private func alertRow(
        icon: String,
        title: String,
        tint: Color,
        enabled: Bool,
        threshold: Double?,
        sustained: Int?,
        unit: String?,
        thresholdRange: ClosedRange<Double>?,
        sustainedRange: ClosedRange<Int>?,
        onToggle: @escaping (Bool) -> Void,
        onThreshold: ((Double) -> Void)?,
        onSustained: ((Int) -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                    .frame(width: 16)
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { enabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
            }

            if enabled {
                VStack(spacing: 6) {
                    if let threshold, let unit, let range = thresholdRange, let onThreshold {
                        HStack(spacing: 8) {
                            Text("Threshold")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 64, alignment: .leading)
                            Slider(
                                value: Binding(
                                    get: { threshold },
                                    set: { onThreshold($0) }
                                ),
                                in: range,
                                step: 5
                            )
                            .controlSize(.mini)
                            Text(String(format: "%.0f%@", threshold, unit))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }

                    if let sustained, let range = sustainedRange, let onSustained {
                        HStack(spacing: 8) {
                            Text("Sustained")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 64, alignment: .leading)
                            Slider(
                                value: Binding(
                                    get: { Double(sustained) },
                                    set: { onSustained(Int($0)) }
                                ),
                                in: Double(range.lowerBound)...Double(range.upperBound),
                                step: 5
                            )
                            .controlSize(.mini)
                            Text("\(sustained)s")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
                .padding(.leading, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .animation(.smooth(duration: 0.25), value: enabled)
    }

    // MARK: - Simple Toggle Row

    private func simpleToggleRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        enabled: Bool,
        onToggle: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { enabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Test Button

    private var testButton: some View {
        HStack {
            Spacer()
            Button {
                sendTestNotification()
            } label: {
                Label("Test Notification", systemImage: "bell.badge")
                    .font(.caption)
            }
            .buttonStyle(.dark)
            .disabled(notificationStatus == .denied)
        }
    }

    // MARK: - Helpers

    private func setConfig(_ serverID: UUID, _ mutate: (inout AlertConfig) -> Void) {
        var config = alertManager.config(for: serverID)
        mutate(&config)
        alertManager.setConfig(config, for: serverID)
    }

    private func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                notificationStatus = settings.authorizationStatus
            }
        }
    }

    private func sendTestNotification() {
        guard let serverID = selectedServerID,
              let server = serverManager.servers.first(where: { $0.id == serverID }) else {
            return
        }
        alertManager.fireTestAlert(serverID: serverID, serverName: server.name)
    }
}

// MARK: - Webhook Info Button

private struct WebhookInfoButton: View {
    let title: String
    let message: String
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 280)
            .preferredColorScheme(.dark)
        }
    }
}
