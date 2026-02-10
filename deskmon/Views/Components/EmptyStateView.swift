import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 40))
                .foregroundStyle(Theme.cardBorder)

            Text("No Servers")
                .font(.headline)

            Text("Add a server to start monitoring")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
