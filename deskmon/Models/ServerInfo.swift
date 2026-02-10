import Foundation

@MainActor
@Observable
final class ServerInfo: Identifiable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var token: String
    var status: ServerStatus = .offline
    var stats: ServerStats? = nil
    var containers: [DockerContainer] = []

    init(id: UUID = UUID(), name: String, host: String, port: Int = 9090, token: String = "") {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.token = token
    }
}
