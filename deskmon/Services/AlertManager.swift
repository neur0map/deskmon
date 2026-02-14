import Foundation
import UserNotifications
import os

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

    private var permissionGranted = false

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
        previousContainerStates.removeValue(forKey: serverID.uuidString)
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
        guard cfg.containerDownEnabled else { return }

        let id = serverID.uuidString
        let previous = previousContainerStates[id] ?? [:]

        for container in containers {
            let prevStatus = previous[container.id]
            // Detect running → stopped transition
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

        // Update previous state
        previousContainerStates[id] = Dictionary(
            uniqueKeysWithValues: containers.map { ($0.id, $0.status.rawValue) }
        )
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

        Self.log.info("Alert fired: \(serverName) — \(title): \(body)")
    }

    // MARK: - Persistence

    private static let configsKey = "alertConfigs"

    init() {
        loadConfigs()
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
