import Foundation

/// Singleton registry that maps Docker container images to their plugins.
///
/// Register plugins once at app startup from `deskmonApp.init()`.
@MainActor
final class PluginRegistry {
    static let shared = PluginRegistry()

    private var plugins: [any ContainerPlugin] = []

    private init() {}

    /// Register a plugin. Silently ignores duplicates (same `id`).
    func register(_ plugin: any ContainerPlugin) {
        guard !plugins.contains(where: { $0.id == plugin.id }) else { return }
        plugins.append(plugin)
    }

    /// Return the first registered plugin whose `matches(imageName:)` returns `true`,
    /// or `nil` if no plugin handles the image.
    func plugin(for imageName: String) -> (any ContainerPlugin)? {
        // Normalise: lowercase, strip tag (everything after the first ":")
        let normalized = imageName.lowercased()
            .components(separatedBy: ":").first ?? imageName.lowercased()
        return plugins.first { $0.matches(imageName: normalized) }
    }
}
