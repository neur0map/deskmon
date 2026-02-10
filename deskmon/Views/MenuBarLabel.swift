import SwiftUI

struct MenuBarLabel: View {
    let status: ServerStatus

    var body: some View {
        switch status {
        case .healthy:
            Image(systemName: "server.rack")
        case .warning:
            Image(systemName: "server.rack")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.orange)
        case .critical:
            Image(systemName: "server.rack")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.red)
        case .offline:
            Image(systemName: "server.rack")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.secondary)
        }
    }
}
