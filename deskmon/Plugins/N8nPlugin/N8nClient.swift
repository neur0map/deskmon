import Foundation

// MARK: - Models

struct N8nWorkflow: Codable, Identifiable {
    let id: String
    let name: String
    let active: Bool
    let updatedAt: String?
    let isArchived: Bool?
}

struct N8nExecution: Codable, Identifiable {
    let id: String
    let finished: Bool
    let mode: String
    let status: String  // "success", "error", "crashed", "running", "waiting"
    let startedAt: String?
    let stoppedAt: String?
    let workflowId: String?
    let workflowData: WorkflowRef?

    struct WorkflowRef: Codable {
        let id: String
        let name: String
    }

    var startedDate: Date? {
        guard let s = startedAt else { return nil }
        // n8n timestamps include milliseconds ("2024-01-01T10:00:00.000Z") which the
        // default ISO8601DateFormatter doesn't handle — enable fractional seconds.
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    var formattedStartTime: String {
        guard let date = startedDate else { return "—" }
        let df = DateFormatter()
        df.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "d MMM, HH:mm"
        return df.string(from: date)
    }
}

private struct N8nListResponse<T: Codable>: Codable {
    let data: [T]
    let nextCursor: String?
}

// Minimal workflow detail model — only used to find webhook trigger nodes.
private struct N8nWorkflowDetail: Codable {
    let nodes: [Node]

    struct Node: Codable {
        let type: String
        let parameters: Parameters?
        struct Parameters: Codable {
            let path: String?
            let httpMethod: String?
        }
    }

    var webhookNode: Node? {
        nodes.first { $0.type == "n8n-nodes-base.webhook" }
    }
}

// MARK: - Client

struct N8nClient {
    let baseURL: String
    let apiKey: String

    private func makeRequest(path: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "X-N8N-API-KEY")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    func fetchWorkflows() async throws -> [N8nWorkflow] {
        let req = try makeRequest(path: "/api/v1/workflows?limit=25")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse { try checkStatus(http) }
        let all = try JSONDecoder().decode(N8nListResponse<N8nWorkflow>.self, from: data).data
        return all.filter { $0.isArchived != true }
    }

    func fetchExecutions(limit: Int = 10) async throws -> [N8nExecution] {
        let req = try makeRequest(path: "/api/v1/executions?limit=\(limit)&includeData=false")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse { try checkStatus(http) }
        return try JSONDecoder().decode(N8nListResponse<N8nExecution>.self, from: data).data
    }

    func fetchRunningExecutions() async throws -> [N8nExecution] {
        let req = try makeRequest(path: "/api/v1/executions?status=running&limit=10&includeData=false")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse { try checkStatus(http) }
        return try JSONDecoder().decode(N8nListResponse<N8nExecution>.self, from: data).data
    }

    /// Returns the webhook path and HTTP method for a workflow's Webhook trigger node,
    /// or `nil` if the workflow has no webhook trigger.
    func fetchWebhookInfo(workflowID: String) async throws -> (path: String, method: String)? {
        let req = try makeRequest(path: "/api/v1/workflows/\(workflowID)")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse { try checkStatus(http) }
        let detail = try JSONDecoder().decode(N8nWorkflowDetail.self, from: data)
        guard let node = detail.webhookNode,
              let path = node.parameters?.path, !path.isEmpty else { return nil }
        let method = node.parameters?.httpMethod ?? "GET"
        return (path: path, method: method)
    }

    /// Trigger a workflow by POSTing to its webhook URL.
    /// Note: no API key is sent — webhook endpoints use their own auth configured in n8n.
    func triggerWebhook(path: String, method: String) async throws {
        guard let url = URL(string: "\(baseURL)/webhook/\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = method
        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse {
            try checkStatus(http)
        }
    }

    private func checkStatus(_ response: HTTPURLResponse) throws {
        if response.statusCode == 401 { throw N8nError.unauthorized }
        guard (200...299).contains(response.statusCode) else {
            throw N8nError.httpError(response.statusCode)
        }
    }
}

// MARK: - Errors

enum N8nError: LocalizedError {
    case unauthorized
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized: "Invalid API key — check your n8n settings"
        case .httpError(let code): "n8n returned HTTP \(code)"
        }
    }
}

// MARK: - Keychain

extension KeychainStore {
    static func saveN8nAPIKey(_ key: String, serverID: UUID) throws {
        guard let data = key.data(using: .utf8) else { throw KeychainError.dataConversion }
        try save(account: "n8n-apikey-\(serverID.uuidString)", data: data)
    }

    static func loadN8nAPIKey(serverID: UUID) -> String? {
        guard let data = load(account: "n8n-apikey-\(serverID.uuidString)") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteN8nAPIKey(serverID: UUID) {
        delete(account: "n8n-apikey-\(serverID.uuidString)")
    }
}
