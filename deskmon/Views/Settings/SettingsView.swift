import SwiftUI

struct SettingsView: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(AlertManager.self) private var alertManager
    @State private var showingAddServer = false
    @State private var editingServer: ServerInfo?

    var body: some View {
        TabView(selection: Binding(
            get: { alertManager.selectedSettingsTab },
            set: { alertManager.selectedSettingsTab = $0 }
        )) {
            Tab("Servers", systemImage: "server.rack", value: "servers") {
                serversTab
            }

            Tab("Alerts", systemImage: "bell.badge", value: "alerts") {
                AlertConfigView()
            }

            Tab("General", systemImage: "gear", value: "general") {
                generalTab
            }
        }
        .frame(width: 480, height: 380)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddServer) {
            AddServerSheet()
        }
        .sheet(item: $editingServer) { server in
            EditServerSheet(server: server)
        }
    }

    private var serversTab: some View {
        VStack(spacing: 0) {
            List {
                ForEach(serverManager.servers) { server in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(server.status.color)
                            .frame(width: 10, height: 10)
                            .animation(.smooth, value: server.status)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.name)
                                .font(.body.weight(.medium))
                            Text("\(server.username)@\(server.host)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let stats = server.stats {
                            HStack(spacing: 8) {
                                Label(String(format: "%.0f%%", stats.cpu.usagePercent), systemImage: "cpu")
                                    .foregroundStyle(Theme.cpu)
                                Label(String(format: "%.0f%%", stats.memory.usagePercent), systemImage: "memorychip")
                                    .foregroundStyle(Theme.memory)
                            }
                            .font(.caption.monospacedDigit())
                        }
                    }
                    .contextMenu {
                        Button("Edit") {
                            editingServer = server
                        }
                        Button("Delete", role: .destructive) {
                            withAnimation {
                                serverManager.deleteServer(server)
                            }
                        }
                    }
                }
            }

            HStack {
                Button { showingAddServer = true } label: {
                    Label("Add Server", systemImage: "plus")
                }
                Spacer()
            }
            .padding(12)
        }
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Refresh Interval")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("3 seconds")
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Version")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("1.0.0")
                    .font(.body)
            }

            Spacer()
        }
        .padding(20)
    }
}
