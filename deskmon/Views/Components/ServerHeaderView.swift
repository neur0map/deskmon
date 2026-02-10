import SwiftUI

struct ServerHeaderView: View {
    let server: ServerInfo

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.headline)

                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(server.status.color)
                            .frame(width: 7, height: 7)
                            .animation(.smooth, value: server.status)
                        Text(server.status.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let stats = server.stats {
                        Text("Up \(ByteFormatter.formatUptime(stats.uptimeSeconds))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.cardBorder, in: Capsule())
                    }
                }
            }

            Spacer()

            Text(server.host)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .tintedCardStyle(cornerRadius: 12, tint: server.status.color)
    }
}
