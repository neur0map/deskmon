import SwiftUI

struct FooterView: View {
    @Environment(ServerManager.self) private var serverManager
    @Environment(\.openWindow) private var openWindow
    var onAddServer: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button {
                openWindow(id: "main-dashboard")
            } label: {
                Label("Dashboard", systemImage: "macwindow")
            }
            .buttonStyle(.darkProminent)

            Spacer()

            Button(action: onAddServer) {
                Image(systemName: "plus")
            }
            .buttonStyle(.dark)

            Button(action: onSettings) {
                Image(systemName: "gear")
            }
            .buttonStyle(.dark)

            Button {
                serverManager.stopPolling()
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.dark)
        }
    }
}
