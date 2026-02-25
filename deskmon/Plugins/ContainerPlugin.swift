import SwiftUI

/// Context provided to a plugin when it renders its detail view.
struct PluginContext {
    /// The server on which this container is running.
    let serverID: UUID
    /// The Docker container the plugin is rendering.
    let container: DockerContainer
}

// MARK: - Plugin Alert Types

struct PluginAlertMetricDefinition {
    /// Stable identifier, e.g. "execution_failed".
    let key: String
    /// Shown in notification title.
    let displayName: String
    /// Shown in config UI.
    let description: String
    /// Advisory poll interval; ServerManager polls on its own 60s timer.
    let pollIntervalSeconds: Int
}

enum PluginAlertResult {
    case ok
    case firing(message: String)
}

struct PluginAlertContext {
    let serverID: UUID
    let container: DockerContainer
    /// Opens (or reuses) an SSH tunnel to the given remote port; returns "http://127.0.0.1:{port}".
    let getURL: (Int) async throws -> String
}

// MARK: - Protocol

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

    /// Alertable metrics this plugin can evaluate.
    var alertMetrics: [PluginAlertMetricDefinition] { get }

    /// Evaluate a single metric and return `.ok` or `.firing(message:)`.
    func evaluateAlert(metricKey: String, context: PluginAlertContext) async -> PluginAlertResult
}

// MARK: - Default Implementations

extension ContainerPlugin {
    var alertMetrics: [PluginAlertMetricDefinition] { [] }
    func evaluateAlert(metricKey: String, context: PluginAlertContext) async -> PluginAlertResult { .ok }
}
