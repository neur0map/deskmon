import SwiftUI

struct N8nPlugin: ContainerPlugin {
    let id = "n8n"

    func matches(imageName: String) -> Bool {
        // Matches "n8nio/n8n", "docker.n8n.io/n8nio/n8n", "n8n", "custom/n8n", etc.
        imageName.contains("n8n")
    }

    func makeDetailView(context: PluginContext) -> AnyView {
        AnyView(N8nDetailView(context: context))
    }
}
