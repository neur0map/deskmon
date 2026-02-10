import Foundation
import os

// MARK: - Agent API Response

/// Matches the actual JSON shape from deskmon-agent GET /stats
struct AgentStatsResponse: Codable, Sendable {
    let system: ServerStats
    let containers: [DockerContainer]
    let processes: [ProcessInfo]?
    let services: [ServiceInfo]?
}

// MARK: - Container Actions

enum ContainerAction: String, Sendable {
    case start, stop, restart
}

struct ControlResponse: Codable, Sendable {
    let message: String?
    let error: String?
}

// MARK: - Errors

enum AgentError: LocalizedError, Sendable, Equatable {
    case invalidURL
    case httpError(Int)
    case unauthorized
    case unreachable

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid server URL"
        case .httpError(let code): "HTTP \(code)"
        case .unauthorized: "Invalid token"
        case .unreachable: "Server unreachable"
        }
    }
}

// MARK: - Connection Result

enum ConnectionResult: Sendable {
    case success(AgentStatsResponse)
    case unauthorized
    case unreachable
    case error(String)
}

// MARK: - SSE Events

/// Decoded event from the SSE stream.
enum ServerEvent: Sendable {
    case system(ServerStats, [ProcessInfo])
    case docker([DockerContainer])
    case services([ServiceInfo])
    case keepalive
}

/// Matches the "system" SSE event payload from the agent.
private struct SystemEventPayload: Codable, Sendable {
    let system: ServerStats
    let processes: [ProcessInfo]
}

// MARK: - Client

final class AgentClient: Sendable {
    static let shared = AgentClient()

    private static let log = Logger(subsystem: "prowlsh.deskmon", category: "AgentClient")

    /// Two-step handshake: health check (reachable?) then stats fetch (token valid?).
    /// Returns a structured result so the caller can show the right error.
    func verifyConnection(host: String, port: Int, token: String) async -> ConnectionResult {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 1: Health check — is the agent reachable?
        let reachable = await checkHealth(host: host, port: port)
        guard reachable else {
            return .unreachable
        }

        // Step 2: Fetch stats with token — is the token valid?
        do {
            let response = try await fetchStats(host: host, port: port, token: trimmedToken)
            return .success(response)
        } catch AgentError.unauthorized {
            return .unauthorized
        } catch {
            return .error(error.localizedDescription)
        }
    }

    /// Fetch full stats (system + containers) from the agent.
    func fetchStats(host: String, port: Int, token: String) async throws -> AgentStatsResponse {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: "http://\(trimmedHost):\(port)/stats") else {
            Self.log.error("Invalid URL: http://\(trimmedHost):\(port)/stats")
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        if !trimmedToken.isEmpty {
            request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        }

        Self.log.info("GET \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                Self.log.error("No HTTP response from \(url.absoluteString)")
                throw AgentError.httpError(0)
            }

            Self.log.info("\(url.absoluteString) -> \(http.statusCode)")

            switch http.statusCode {
            case 200:
                break
            case 401:
                throw AgentError.unauthorized
            default:
                throw AgentError.httpError(http.statusCode)
            }

            return try JSONDecoder().decode(AgentStatsResponse.self, from: data)
        } catch let error as AgentError {
            throw error
        } catch let error as DecodingError {
            Self.log.error("Decode error for \(url.absoluteString): \(error)")
            throw error
        } catch {
            let nsError = error as NSError
            Self.log.error("Network error for \(url.absoluteString): domain=\(nsError.domain) code=\(nsError.code) \(nsError.localizedDescription)")
            throw error
        }
    }

    /// Perform a container action (start/stop/restart).
    func performContainerAction(host: String, port: Int, token: String, containerID: String, action: ContainerAction) async throws -> String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: "http://\(trimmedHost):\(port)/containers/\(containerID)/\(action.rawValue)") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        if !trimmedToken.isEmpty {
            request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        }

        Self.log.info("POST \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AgentError.httpError(0)
        }

        if http.statusCode == 401 {
            throw AgentError.unauthorized
        }

        let decoded = try JSONDecoder().decode(ControlResponse.self, from: data)

        if decoded.error != nil {
            throw AgentError.httpError(http.statusCode)
        }

        return decoded.message ?? action.rawValue
    }

    /// Kill a process by PID.
    func killProcess(host: String, port: Int, token: String, pid: Int32) async throws -> String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: "http://\(trimmedHost):\(port)/processes/\(pid)/kill") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        if !trimmedToken.isEmpty {
            request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        }

        Self.log.info("POST \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AgentError.httpError(0)
        }

        if http.statusCode == 401 {
            throw AgentError.unauthorized
        }

        let decoded = try JSONDecoder().decode(ControlResponse.self, from: data)

        if decoded.error != nil {
            throw AgentError.httpError(http.statusCode)
        }

        return decoded.message ?? "killed"
    }

    /// Restart the agent process.
    func restartAgent(host: String, port: Int, token: String) async throws -> String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: "http://\(trimmedHost):\(port)/agent/restart") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        if !trimmedToken.isEmpty {
            request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        }

        Self.log.info("POST \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AgentError.httpError(0)
        }

        if http.statusCode == 401 {
            throw AgentError.unauthorized
        }

        let decoded = try JSONDecoder().decode(ControlResponse.self, from: data)
        return decoded.message ?? "restarting"
    }

    // MARK: - Service Configuration

    /// Send a service password/credential to the agent for a specific plugin.
    func configureService(host: String, port: Int, token: String, pluginId: String, password: String) async throws -> String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: "http://\(trimmedHost):\(port)/services/\(pluginId)/configure") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !trimmedToken.isEmpty {
            request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        }

        let body = ["password": password]
        request.httpBody = try JSONEncoder().encode(body)

        Self.log.info("POST \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AgentError.httpError(0)
        }

        if http.statusCode == 401 {
            throw AgentError.unauthorized
        }

        let decoded = try JSONDecoder().decode(ControlResponse.self, from: data)

        if decoded.error != nil {
            throw AgentError.httpError(http.statusCode)
        }

        return decoded.message ?? "configured"
    }

    // MARK: - SSE Streaming

    /// Opens a persistent SSE connection to GET /stats/stream and yields decoded events.
    func streamStats(host: String, port: Int, token: String) -> AsyncThrowingStream<ServerEvent, Error> {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        return AsyncThrowingStream { continuation in
            let task = Task {
                guard let url = URL(string: "http://\(trimmedHost):\(port)/stats/stream") else {
                    continuation.finish(throwing: AgentError.invalidURL)
                    return
                }

                var request = URLRequest(url: url)
                if !trimmedToken.isEmpty {
                    request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
                }
                // No timeout — SSE is a long-lived connection
                request.timeoutInterval = 0

                Self.log.info("SSE connecting to \(url.absoluteString)")

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AgentError.httpError(0))
                        return
                    }

                    if http.statusCode == 401 {
                        continuation.finish(throwing: AgentError.unauthorized)
                        return
                    }

                    guard http.statusCode == 200 else {
                        continuation.finish(throwing: AgentError.httpError(http.statusCode))
                        return
                    }

                    Self.log.info("SSE stream connected")

                    var currentEvent = ""
                    var dataBuffer = ""

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        if line.hasPrefix("event: ") {
                            currentEvent = String(line.dropFirst(7))
                        } else if line.hasPrefix("data: ") {
                            dataBuffer = String(line.dropFirst(6))
                        } else if line.hasPrefix(":") {
                            // Comment line (keepalive)
                            continuation.yield(.keepalive)
                        } else if line.isEmpty && !currentEvent.isEmpty {
                            // Empty line = end of event
                            if let event = Self.decodeSSEEvent(type: currentEvent, data: dataBuffer) {
                                continuation.yield(event)
                            }
                            currentEvent = ""
                            dataBuffer = ""
                        }
                    }

                    continuation.finish()
                } catch {
                    Self.log.error("SSE stream error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func decodeSSEEvent(type: String, data: String) -> ServerEvent? {
        guard let jsonData = data.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()

        switch type {
        case "system":
            guard let payload = try? decoder.decode(SystemEventPayload.self, from: jsonData) else { return nil }
            return .system(payload.system, payload.processes)
        case "docker":
            guard let containers = try? decoder.decode([DockerContainer].self, from: jsonData) else { return nil }
            return .docker(containers)
        case "services":
            guard let services = try? decoder.decode([ServiceInfo].self, from: jsonData) else { return nil }
            return .services(services)
        default:
            return nil
        }
    }

    /// Lightweight health check — returns true if agent responds 200.
    func checkHealth(host: String, port: Int) async -> Bool {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: "http://\(trimmedHost):\(port)/health") else {
            Self.log.error("Invalid health URL: http://\(trimmedHost):\(port)/health")
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        Self.log.info("GET \(url.absoluteString) (health check)")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            Self.log.info("Health check -> \(status)")
            return status == 200
        } catch {
            let nsError = error as NSError
            Self.log.error("Health check failed: domain=\(nsError.domain) code=\(nsError.code) \(nsError.localizedDescription)")
            return false
        }
    }
}
