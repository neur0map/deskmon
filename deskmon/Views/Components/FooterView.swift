import SwiftUI

struct FooterView: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(AlertManager.self) private var alertManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 6) {
            Button {
                let panel = NSApp.keyWindow
                openWindow(id: "main-dashboard")
                NSApp.activate(ignoringOtherApps: true)
                panel?.close()
            } label: {
                Label("Dashboard", systemImage: "macwindow")
            }
            .buttonStyle(.darkProminent)

            Spacer()

            Button {
                alertManager.selectedSettingsTab = "alerts"
                openSettings()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: alertManager.hasUnacknowledgedAlerts ? "bell.badge.fill" : "bell")
                        .font(.caption2)
                    if alertManager.hasUnacknowledgedAlerts {
                        Circle()
                            .fill(Theme.critical)
                            .frame(width: 5, height: 5)
                            .offset(x: 3, y: -3)
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(alertManager.hasUnacknowledgedAlerts ? Theme.critical : .secondary)

            Button {
                serverManager.stopStreaming()
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.dark)
        }
    }
}
