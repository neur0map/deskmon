import SwiftUI

struct ServerHeaderView: View {
    let server: ServerInfo

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 12){
                Image(systemName: "server.rack")
                    .font(.title2)
                    .foregroundStyle(.primary)
                Text(server.name)
                    .font(.headline)
            }
            
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(server.status.color)
                        .frame(width: 10, height: 10)
                        .animation(.smooth, value: server.status)
                    Text(server.status.label)
                        .font(.subheadline.weight(.medium))
                }
                
                Divider().frame(height: 16).overlay(Theme.cardBorder)
                
                Label("\(server.username)@\(server.host)", systemImage: "network")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                if let stats = server.stats {
                    Divider().frame(height: 16).overlay(Theme.cardBorder)
                    
                    Label("Up \(ByteFormatter.formatUptime(stats.uptimeSeconds))", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 0)
            }
        }
        .colorScheme(.dark)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .tintedCardStyle(cornerRadius: 12, tint: server.status.color)
    }
}
