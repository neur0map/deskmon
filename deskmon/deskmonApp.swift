import SwiftUI

@main
struct deskmonApp: App {
    @State private var serverManager = ServerManager()

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environment(serverManager)
        } label: {
            MenuBarLabel(status: serverManager.currentStatus)
        }
        .menuBarExtraStyle(.window)

        Window("Deskmon", id: "main-dashboard") {
            MainDashboardView()
                .environment(serverManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 640)

        Settings {
            SettingsView()
                .environment(serverManager)
        }
    }
}
