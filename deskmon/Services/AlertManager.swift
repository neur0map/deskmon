import Foundation
import UserNotifications
import os

// MARK: - Notification Delegate

/// Allows notifications to display as banners even while the app is in the foreground.
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Alert Configuration (per-server)

struct AlertConfig: Codable, Sendable {
    var cpuEnabled: Bool = true
    var cpuThreshold: Double = 90
    var cpuSustained: Int = 30

    var memoryEnabled: Bool = true
    var memoryThreshold: Double = 95
    var memorySustained: Int = 30

    var diskEnabled: Bool = true
    var diskThreshold: Double = 90

    var containerDownEnabled: Bool = true

    var networkErrorsEnabled: Bool = true
    var networkErrorsSustained: Int = 10

    // Container metrics
    var containerCPUEnabled: Bool = false
    var containerCPUThreshold: Double = 80
    var containerCPUSustained: Int = 60

    var containerMemoryEnabled: Bool = false
    var containerMemoryThreshold: Double = 90
    var containerMemorySustained: Int = 30

    var containerUnhealthyEnabled: Bool = true
    var containerRestartSpikeEnabled: Bool = true
    var containerRestartThreshold: Int = 5

    // Plugin alerts
    var pluginAlertsEnabled: Bool = true

    // Slack
    var slackEnabled: Bool = false
    var slackWebhookURL: String = ""

    // Discord
    var discordEnabled: Bool = false
    var discordWebhookURL: String = ""

    // Generic webhook
    var genericWebhookEnabled: Bool = false
    var genericWebhookURL: String = ""
}

// MARK: - Fired Alert

struct FiredAlert: Identifiable {
    let id = UUID()
    let timestamp: Date
    let serverName: String
    let title: String
    let body: String
    let serverID: UUID
}

// MARK: - Alert Manager

@MainActor
@Observable
final class AlertManager {

    private static let log = Logger(subsystem: "prowlsh.deskmon", category: "AlertManager")
    private static let cooldown: TimeInterval = 300 // 5 minutes

    /// Per-server alert configs, keyed by server UUID string.
    private var configs: [String: AlertConfig] = [:]

    // Sustained-time tracking: key = "serverID-alertType"
    private var firstBreachTime: [String: Date] = [:]

    // Cooldown tracking: key = "serverID-alertType"
    private var lastFired: [String: Date] = [:]

    // Track previous container states to detect running → stopped transitions
    private var previousContainerStates: [String: [String: String]] = [:] // serverID → [containerID: status]

    // Container health and restart tracking
    private var previousContainerHealthStates: [String: [String: String]] = [:]
    private var previousRestartCounts: [String: [String: Int]] = [:]

    private var permissionGranted = false
    private let notificationDelegate = NotificationDelegate()

    // MARK: - Alert History

    private(set) var recentAlerts: [FiredAlert] = []
    var hasUnacknowledgedAlerts: Bool { !recentAlerts.isEmpty }
    func clearAlerts() { recentAlerts = [] }

    var selectedSettingsTab: String = "servers"

    // MARK: - Public API

    func requestPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    Task { @MainActor in
                        self.permissionGranted = granted
                        if let error {
                            Self.log.error("Notification permission error: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                Task { @MainActor in
                    self.permissionGranted = settings.authorizationStatus == .authorized
                }
            }
        }
    }

    func config(for serverID: UUID) -> AlertConfig {
        configs[serverID.uuidString] ?? AlertConfig()
    }

    func setConfig(_ config: AlertConfig, for serverID: UUID) {
        configs[serverID.uuidString] = config
        saveConfigs()
    }

    func removeConfig(for serverID: UUID) {
        configs.removeValue(forKey: serverID.uuidString)
        // Clean up tracking state
        let prefix = serverID.uuidString
        firstBreachTime = firstBreachTime.filter { !$0.key.hasPrefix(prefix) }
        lastFired = lastFired.filter { !$0.key.hasPrefix(prefix) }
        previousContainerStates.removeValue(forKey: prefix)
        previousContainerHealthStates.removeValue(forKey: prefix)
        previousRestartCounts.removeValue(forKey: prefix)
        saveConfigs()
    }

    // MARK: - Evaluate Events

    /// Called on every SSE system event.
    func evaluateSystem(serverID: UUID, serverName: String, stats: ServerStats) {
        let cfg = config(for: serverID)
        let id = serverID.uuidString

        // CPU
        if cfg.cpuEnabled {
            evaluateSustained(
                key: "\(id)-cpu",
                breached: stats.cpu.usagePercent > cfg.cpuThreshold,
                sustainedSeconds: cfg.cpuSustained,
                serverName: serverName,
                title: "CPU Critical",
                body: String(format: "CPU at %.0f%% for %ds", stats.cpu.usagePercent, cfg.cpuSustained),
                serverID: serverID
            )
        }

        // Memory
        if cfg.memoryEnabled {
            evaluateSustained(
                key: "\(id)-memory",
                breached: stats.memory.usagePercent > cfg.memoryThreshold,
                sustainedSeconds: cfg.memorySustained,
                serverName: serverName,
                title: "Memory Critical",
                body: String(format: "Memory at %.0f%% for %ds", stats.memory.usagePercent, cfg.memorySustained),
                serverID: serverID
            )
        }

        // Disk (per mount)
        if cfg.diskEnabled {
            for disk in stats.disks {
                if disk.usagePercent > cfg.diskThreshold {
                    fireIfCooldown(
                        key: "\(id)-disk-\(disk.mountPoint)",
                        serverName: serverName,
                        title: "Disk Critical",
                        body: String(format: "%@ at %.0f%%", disk.label, disk.usagePercent),
                        serverID: serverID
                    )
                }
            }
        }

        // Network errors
        if cfg.networkErrorsEnabled {
            let phys = stats.network.physical
            let hasErrors = phys.hasErrors
            evaluateSustained(
                key: "\(id)-neterr",
                breached: hasErrors,
                sustainedSeconds: cfg.networkErrorsSustained,
                serverName: serverName,
                title: "Network Errors",
                body: "Packet errors/drops detected on physical interfaces",
                serverID: serverID
            )
        }
    }

    /// Called on every SSE docker event.
    func evaluateContainers(serverID: UUID, serverName: String, containers: [DockerContainer]) {
        let cfg = config(for: serverID)
        let id = serverID.uuidString
        let previous = previousContainerStates[id] ?? [:]

        // Container down
        if cfg.containerDownEnabled {
            for container in containers {
                let prevStatus = previous[container.id]
                if prevStatus == "running" && container.status != .running {
                    fireIfCooldown(
                        key: "\(id)-container-\(container.id)",
                        serverName: serverName,
                        title: "Container Down",
                        body: "\(container.name) stopped",
                        serverID: serverID
                    )
                }
            }
        }

        // Update previous state
        previousContainerStates[id] = Dictionary(
            uniqueKeysWithValues: containers.map { ($0.id, $0.status.rawValue) }
        )

        // Container CPU
        if cfg.containerCPUEnabled {
            for c in containers where c.status == .running {
                evaluateSustained(
                    key: "\(id)-ccpu-\(c.id)",
                    breached: c.cpuPercent > cfg.containerCPUThreshold,
                    sustainedSeconds: cfg.containerCPUSustained,
                    serverName: serverName,
                    title: "Container CPU",
                    body: String(format: "%@ CPU at %.0f%%", c.name, c.cpuPercent),
                    serverID: serverID
                )
            }
        }

        // Container memory
        if cfg.containerMemoryEnabled {
            for c in containers where c.status == .running {
                evaluateSustained(
                    key: "\(id)-cmem-\(c.id)",
                    breached: c.memoryPercent > cfg.containerMemoryThreshold,
                    sustainedSeconds: cfg.containerMemorySustained,
                    serverName: serverName,
                    title: "Container Memory",
                    body: String(format: "%@ memory at %.0f%%", c.name, c.memoryPercent),
                    serverID: serverID
                )
            }
        }

        // Container unhealthy
        if cfg.containerUnhealthyEnabled {
            let prevHealth = previousContainerHealthStates[id] ?? [:]
            for c in containers where c.status == .running {
                if prevHealth[c.id] == "healthy" && c.healthStatus == .unhealthy {
                    fireIfCooldown(
                        key: "\(id)-cunhealthy-\(c.id)",
                        serverName: serverName,
                        title: "Container Unhealthy",
                        body: "\(c.name) health check failing",
                        serverID: serverID
                    )
                }
            }
            previousContainerHealthStates[id] = Dictionary(
                uniqueKeysWithValues: containers.map { ($0.id, $0.healthStatus.rawValue) }
            )
        }

        // Container restart spike
        if cfg.containerRestartSpikeEnabled {
            let prevRestarts = previousRestartCounts[id] ?? [:]
            for c in containers {
                let prev = prevRestarts[c.id] ?? 0
                if c.restartCount > cfg.containerRestartThreshold && c.restartCount > prev {
                    fireIfCooldown(
                        key: "\(id)-crestart-\(c.id)",
                        serverName: serverName,
                        title: "Container Restarting",
                        body: "\(c.name) has restarted \(c.restartCount) times",
                        serverID: serverID
                    )
                }
            }
            previousRestartCounts[id] = Dictionary(
                uniqueKeysWithValues: containers.map { ($0.id, $0.restartCount) }
            )
        }
    }

    // MARK: - Plugin Alerts

    func firePluginAlert(key: String, serverName: String, title: String, body: String, serverID: UUID) {
        guard config(for: serverID).pluginAlertsEnabled else { return }
        fireIfCooldown(key: key, serverName: serverName, title: title, body: body, serverID: serverID)
    }

    /// Fires a test alert immediately — bypasses cooldown, always delivers macOS notification + Slack if configured.
    func fireTestAlert(serverID: UUID, serverName: String) {
        let title = "Test Alert"
        let body = "Notifications are working correctly."

        let content = UNMutableNotificationContent()
        content.title = "\(serverName) — \(title)"
        content.body = body
        content.sound = .default
        content.threadIdentifier = serverID.uuidString

        let request = UNNotificationRequest(
            identifier: "test-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Self.log.error("Failed to deliver test notification: \(error.localizedDescription)")
            }
        }

        let cfg = config(for: serverID)
        if cfg.slackEnabled, !cfg.slackWebhookURL.isEmpty {
            let webhookURL = cfg.slackWebhookURL
            Task { await Self.fireSlack(webhookURL: webhookURL, serverName: serverName, title: title, body: body) }
        }
        if cfg.discordEnabled, !cfg.discordWebhookURL.isEmpty {
            let webhookURL = cfg.discordWebhookURL
            Task { await Self.fireDiscord(webhookURL: webhookURL, serverName: serverName, title: title, body: body) }
        }
        if cfg.genericWebhookEnabled, !cfg.genericWebhookURL.isEmpty {
            let webhookURL = cfg.genericWebhookURL
            Task { await Self.fireGenericWebhook(webhookURL: webhookURL, serverName: serverName, title: title, body: body) }
        }
    }

    // MARK: - Private

    private func evaluateSustained(
        key: String,
        breached: Bool,
        sustainedSeconds: Int,
        serverName: String,
        title: String,
        body: String,
        serverID: UUID
    ) {
        if breached {
            if firstBreachTime[key] == nil {
                firstBreachTime[key] = Date()
            }
            if let start = firstBreachTime[key],
               Date().timeIntervalSince(start) >= Double(sustainedSeconds) {
                fireIfCooldown(key: key, serverName: serverName, title: title, body: body, serverID: serverID)
            }
        } else {
            firstBreachTime.removeValue(forKey: key)
        }
    }

    private func fireIfCooldown(key: String, serverName: String, title: String, body: String, serverID: UUID) {
        if let last = lastFired[key], Date().timeIntervalSince(last) < Self.cooldown {
            return // Still in cooldown
        }

        lastFired[key] = Date()
        firstBreachTime.removeValue(forKey: key) // Reset sustained tracking

        // Record in history
        let fired = FiredAlert(timestamp: Date(), serverName: serverName, title: title, body: body, serverID: serverID)
        recentAlerts.insert(fired, at: 0)
        if recentAlerts.count > 50 { recentAlerts = Array(recentAlerts.prefix(50)) }

        let content = UNMutableNotificationContent()
        content.title = "\(serverName) — \(title)"
        content.body = body
        content.sound = .default
        content.threadIdentifier = serverID.uuidString

        let request = UNNotificationRequest(
            identifier: "\(key)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Fire immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Self.log.error("Failed to deliver notification: \(error.localizedDescription)")
            }
        }

        let cfg = config(for: serverID)
        if cfg.slackEnabled, !cfg.slackWebhookURL.isEmpty {
            let webhookURL = cfg.slackWebhookURL
            Task { await Self.fireSlack(webhookURL: webhookURL, serverName: serverName, title: title, body: body) }
        }
        if cfg.discordEnabled, !cfg.discordWebhookURL.isEmpty {
            let webhookURL = cfg.discordWebhookURL
            Task { await Self.fireDiscord(webhookURL: webhookURL, serverName: serverName, title: title, body: body) }
        }
        if cfg.genericWebhookEnabled, !cfg.genericWebhookURL.isEmpty {
            let webhookURL = cfg.genericWebhookURL
            Task { await Self.fireGenericWebhook(webhookURL: webhookURL, serverName: serverName, title: title, body: body) }
        }

        Self.log.info("Alert fired: \(serverName) — \(title): \(body)")
    }

    private static func fireSlack(webhookURL: String, serverName: String, title: String, body: String) async {
        guard let url = URL(string: webhookURL) else { return }
        let payload = ["text": "*\(serverName)* — \(title)\n\(body)"]
        guard let data = try? JSONEncoder().encode(payload) else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try? await URLSession.shared.data(for: req)
    }

    private static func fireDiscord(webhookURL: String, serverName: String, title: String, body: String) async {
        guard let url = URL(string: webhookURL) else { return }
        let payload = ["content": "**\(serverName)** — \(title)\n\(body)"]
        guard let data = try? JSONEncoder().encode(payload) else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try? await URLSession.shared.data(for: req)
    }

    private static func fireGenericWebhook(webhookURL: String, serverName: String, title: String, body: String) async {
        struct Payload: Encodable {
            let serverName: String
            let title: String
            let body: String
            let timestamp: String
        }
        guard let url = URL(string: webhookURL) else { return }
        let payload = Payload(serverName: serverName, title: title, body: body,
                              timestamp: ISO8601DateFormatter().string(from: Date()))
        guard let data = try? JSONEncoder().encode(payload) else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try? await URLSession.shared.data(for: req)
    }

    // MARK: - Persistence

    private static let configsKey = "alertConfigs"

    init() {
        loadConfigs()
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    private func loadConfigs() {
        guard let data = UserDefaults.standard.data(forKey: Self.configsKey),
              let decoded = try? JSONDecoder().decode([String: AlertConfig].self, from: data) else {
            return
        }
        configs = decoded
    }

    private func saveConfigs() {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        UserDefaults.standard.set(data, forKey: Self.configsKey)
    }
}
