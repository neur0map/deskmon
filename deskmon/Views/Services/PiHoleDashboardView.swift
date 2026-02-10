import SwiftUI

struct PiHoleDashboardView: View {
    @Environment(ServerManager.self) private var serverManager
    let service: ServiceInfo

    @State private var piholePassword = ""
    @State private var isAuthenticating = false
    @State private var authError: String?

    private var accent: Color { serviceAccent(for: "pihole") }

    private var queriesToday: Int64 { service.stats["queriesToday"]?.intValue ?? 0 }
    private var adsBlocked: Int64 { service.stats["adsBlockedToday"]?.intValue ?? 0 }
    private var adsPercent: Double { service.stats["adsPercentToday"]?.doubleValue ?? 0 }
    private var domainsBlocked: Int64 { service.stats["domainsBlocked"]?.intValue ?? 0 }
    private var uniqueClients: Int64 { service.stats["uniqueClients"]?.intValue ?? service.stats["activeClients"]?.intValue ?? 0 }
    private var queriesForwarded: Int64 { service.stats["queriesForwarded"]?.intValue ?? 0 }
    private var queriesCached: Int64 { service.stats["queriesCached"]?.intValue ?? 0 }
    private var uniqueDomains: Int64 { service.stats["uniqueDomains"]?.intValue ?? 0 }
    private var piStatus: String { service.stats["status"]?.stringValue ?? service.status }
    private var version: String { service.stats["version"]?.stringValue ?? "" }
    private var authRequired: Bool { service.stats["authRequired"]?.boolValue == true }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                if authRequired {
                    authRequiredCard
                } else {
                    statsGrid
                    breakdownCard
                    infoCard
                }
            }
            .padding(20)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: service.icon)
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.title3.weight(.semibold))
                HStack(spacing: 6) {
                    Circle()
                        .fill(service.isRunning ? Theme.healthy : Theme.critical)
                        .frame(width: 8, height: 8)
                    Text(piStatus.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !version.isEmpty {
                        Text(version)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .tintedCardStyle(cornerRadius: 12, tint: accent)
    }

    // MARK: - Auth Required

    private var authRequiredCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.largeTitle)
                .foregroundStyle(accent.opacity(0.6))

            Text("Authentication Required")
                .font(.headline)

            Text("Pi-hole v6 requires a password to access detailed stats.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                SecureField("Pi-hole password", text: $piholePassword)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { authenticate() }

                Button {
                    authenticate()
                } label: {
                    HStack(spacing: 6) {
                        if isAuthenticating {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Connect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(piholePassword.isEmpty || isAuthenticating)

                if let authError {
                    Text(authError)
                        .font(.caption)
                        .foregroundStyle(Theme.critical)
                }
            }
            .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardStyle(cornerRadius: 12)
    }

    private func authenticate() {
        guard !piholePassword.isEmpty else { return }
        isAuthenticating = true
        authError = nil

        Task {
            do {
                _ = try await serverManager.configureService(pluginId: "pihole", password: piholePassword)
                piholePassword = ""
            } catch {
                authError = error.localizedDescription
            }
            isAuthenticating = false
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statTile(
                "Queries",
                value: formatLargeNumber(queriesToday),
                icon: "magnifyingglass",
                tint: accent
            )
            statTile(
                "Blocked",
                value: String(format: "%.1f%%", adsPercent),
                icon: "hand.raised.fill",
                tint: Theme.critical
            )
            statTile(
                "Blocklist",
                value: formatLargeNumber(domainsBlocked),
                icon: "list.bullet.rectangle",
                tint: Theme.warning
            )
            statTile(
                "Clients",
                value: "\(uniqueClients)",
                icon: "desktopcomputer",
                tint: Theme.memory
            )
        }
    }

    private func statTile(_ label: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint.opacity(0.8))

            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cardStyle(cornerRadius: 12)
    }

    // MARK: - Breakdown

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Query Breakdown")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // Blocked bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Blocked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatLargeNumber(adsBlocked))
                        .font(.caption.monospacedDigit().weight(.medium))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.cardBorder)
                        Capsule()
                            .fill(Theme.critical.gradient)
                            .frame(width: geo.size.width * barFraction(adsBlocked))
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule())
            }

            // Forwarded bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Forwarded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatLargeNumber(queriesForwarded))
                        .font(.caption.monospacedDigit().weight(.medium))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.cardBorder)
                        Capsule()
                            .fill(accent.gradient)
                            .frame(width: geo.size.width * barFraction(queriesForwarded))
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule())
            }

            // Cached bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Cached")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatLargeNumber(queriesCached))
                        .font(.caption.monospacedDigit().weight(.medium))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.cardBorder)
                        Capsule()
                            .fill(Theme.memory.gradient)
                            .frame(width: geo.size.width * barFraction(queriesCached))
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule())
            }
        }
        .padding(14)
        .cardStyle(cornerRadius: 12)
    }

    // MARK: - Info

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow("Unique Domains", value: formatLargeNumber(uniqueDomains))
            Divider().padding(.leading, 12)
            infoRow("Domains on Blocklist", value: formatLargeNumber(domainsBlocked))
            Divider().padding(.leading, 12)
            infoRow("Total Queries", value: formatLargeNumber(queriesToday))
        }
        .cardStyle(cornerRadius: 12)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.monospacedDigit().weight(.medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func barFraction(_ count: Int64) -> CGFloat {
        guard queriesToday > 0 else { return 0 }
        return min(CGFloat(count) / CGFloat(queriesToday), 1)
    }

    private func formatLargeNumber(_ n: Int64) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }
}
