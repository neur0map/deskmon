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

    // MARK: - Alert Metrics

    var alertMetrics: [PluginAlertMetricDefinition] {
        [PluginAlertMetricDefinition(
            key: "execution_failed",
            displayName: "Workflow Execution Failed",
            description: "Alert when a workflow execution fails or crashes (checks last 5 min)",
            pollIntervalSeconds: 60
        )]
    }

    func evaluateAlert(metricKey: String, context: PluginAlertContext) async -> PluginAlertResult {
        guard metricKey == "execution_failed" else { return .ok }
        guard let baseURL = try? await context.getURL(5678) else { return .ok }
        let apiKey = KeychainStore.loadN8nAPIKey(serverID: context.serverID) ?? ""
        guard !apiKey.isEmpty else { return .ok }
        let client = N8nClient(baseURL: baseURL, apiKey: apiKey)
        guard let executions = try? await client.fetchExecutions(limit: 20) else { return .ok }
        let cutoff = Date().addingTimeInterval(-300)
        let failed = executions.filter {
            ($0.status == "error" || $0.status == "crashed") &&
            ($0.startedDate ?? .distantPast) > cutoff
        }
        guard let first = failed.first else { return .ok }
        let verb = first.status == "crashed" ? "crashed" : "failed"
        let name: String
        if let n = first.workflowData?.name {
            name = n
        } else if let wid = first.workflowId {
            name = (try? await client.fetchWorkflowName(id: wid)) ?? wid
        } else {
            name = "unknown"
        }
        return .firing(message: "'\(name)' \(verb)")
    }
}
