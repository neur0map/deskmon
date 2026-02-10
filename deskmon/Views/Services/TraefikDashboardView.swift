import SwiftUI

struct TraefikDashboardView: View {
    let service: ServiceInfo

    private var accent: Color { serviceAccent(for: "traefik") }

    private var httpRouters: Int64 { service.stats["httpRouters"]?.intValue ?? 0 }
    private var httpServices: Int64 { service.stats["httpServices"]?.intValue ?? 0 }
    private var httpMiddlewares: Int64 { service.stats["httpMiddlewares"]?.intValue ?? 0 }
    private var tcpRouters: Int64 { service.stats["tcpRouters"]?.intValue ?? 0 }
    private var tcpServices: Int64 { service.stats["tcpServices"]?.intValue ?? 0 }
    private var udpRouters: Int64 { service.stats["udpRouters"]?.intValue ?? 0 }
    private var udpServices: Int64 { service.stats["udpServices"]?.intValue ?? 0 }
    private var entrypoints: Int64 { service.stats["entrypoints"]?.intValue ?? 0 }
    private var totalRouters: Int64 { service.stats["totalRouters"]?.intValue ?? 0 }
    private var totalServices: Int64 { service.stats["totalServices"]?.intValue ?? 0 }
    private var warnings: Int64 { service.stats["warnings"]?.intValue ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                statsGrid
                protocolBreakdown
                if warnings > 0 {
                    warningsCard
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
                        .fill(service.isRunning ? Theme.healthy : Theme.warning)
                        .frame(width: 8, height: 8)
                    Text(service.status.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if warnings > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.warning)
                    Text("\(warnings)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                }
            }
        }
        .padding(14)
        .tintedCardStyle(cornerRadius: 12, tint: accent)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statTile("Routers", value: "\(totalRouters)", icon: "arrow.triangle.branch", tint: accent)
            statTile("Services", value: "\(totalServices)", icon: "square.stack.3d.up", tint: Theme.memory)
            statTile("Entrypoints", value: "\(entrypoints)", icon: "door.left.hand.open", tint: Theme.healthy)
            statTile("Middlewares", value: "\(httpMiddlewares)", icon: "gearshape.2", tint: Theme.disk)
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

    // MARK: - Protocol Breakdown

    private var protocolBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Protocol Breakdown")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                protocolCard("HTTP", routers: httpRouters, services: httpServices, tint: accent)
                protocolCard("TCP", routers: tcpRouters, services: tcpServices, tint: Theme.warning)
                protocolCard("UDP", routers: udpRouters, services: udpServices, tint: Theme.healthy)
            }
        }
    }

    private func protocolCard(_ label: String, routers: Int64, services: Int64, tint: Color) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            VStack(spacing: 4) {
                HStack {
                    Text("Routers")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(routers)")
                        .font(.caption2.monospacedDigit().weight(.medium))
                }
                HStack {
                    Text("Services")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(services)")
                        .font(.caption2.monospacedDigit().weight(.medium))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .cardStyle(cornerRadius: 10)
    }

    // MARK: - Warnings

    private var warningsCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)
            Text("\(warnings) router/service error\(warnings == 1 ? "" : "s") detected")
                .font(.callout)
                .foregroundStyle(Theme.warning)
            Spacer()
        }
        .padding(14)
        .tintedCardStyle(cornerRadius: 12, tint: Theme.warning)
    }
}
