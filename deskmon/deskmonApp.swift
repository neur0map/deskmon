import SwiftUI

@main
struct deskmonApp: App {
    @State private var serverManager = ServerManager()
    @State private var lockManager = AppLockManager()
    @State private var alertManager = AlertManager()

    init() {
        PluginRegistry.shared.register(N8nPlugin())
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environment(serverManager)
                .environment(lockManager)
                .environment(alertManager)
                .task {
                    serverManager.alertManager = alertManager
                    alertManager.requestPermissionIfNeeded()
                    serverManager.startStreaming()
                }
        } label: {
            MenuBarLabel(status: serverManager.currentStatus)
        }
        .menuBarExtraStyle(.window)

        Window("Deskmon", id: "main-dashboard") {
            MainDashboardView()
                .environment(serverManager)
                .environment(lockManager)
                .environment(alertManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 640)

        Settings {
            SettingsView()
                .environment(serverManager)
                .environment(lockManager)
                .environment(alertManager)
        }
    }
}
