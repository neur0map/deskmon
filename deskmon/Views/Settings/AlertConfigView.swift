import SwiftUI
import UserNotifications

struct AlertConfigView: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(AlertManager.self) private var alertManager
    @State private var selectedServerID: UUID?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

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
        let content = UNMutableNotificationContent()
        content.title = "Deskmon — Test Alert"
        content.body = "Notifications are working correctly."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "test-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
