import SwiftUI

/// Context provided to a plugin when it renders its detail view.
struct PluginContext {
    /// The server on which this container is running.
    let serverID: UUID
    /// The Docker container the plugin is rendering.
    let container: DockerContainer
}

/// A plugin that provides a custom detail view for a specific Docker container type.
///
/// To add a new plugin:
/// 1. Create a type conforming to `ContainerPlugin`
/// 2. Register it at startup: `PluginRegistry.shared.register(MyPlugin())`
@MainActor
protocol ContainerPlugin {
    /// Unique stable identifier, e.g. `"n8n"`.
    var id: String { get }

    /// Return `true` if this plugin should handle a container with the given image name.
    ///
    /// The `imageName` passed here is normalised: lowercased with the tag (`:latest` etc.) stripped.
    func matches(imageName: String) -> Bool

    /// Build the SwiftUI view rendered below the standard container stats in the detail panel.
    func makeDetailView(context: PluginContext) -> AnyView
}
