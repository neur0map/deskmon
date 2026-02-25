import Foundation

struct NetworkSample: Sendable {
    let download: Double
    let upload: Double
    /// Wall-clock time when this sample was received.
    let time: TimeInterval // Date.timeIntervalSinceReferenceDate
}

enum ConnectionPhase: Sendable {
    case disconnected     // No SSH session
    case sshConnecting    // SSH handshake in progress
    case tunnelOpen       // SSH up, tunnel open, fetching snapshot
    case syncing          // Got first snapshot, going-live animation
    case live             // SSE streaming through tunnel
}

@MainActor
@Observable
final class ServerInfo: Identifiable {
    let id: UUID
    var name: String
    var host: String
    var username: String
    var sshPort: Int
    var agentPort: Int
    var hasKeyInstalled: Bool
    var status: ServerStatus = .offline
    var stats: ServerStats? = nil
    var containers: [DockerContainer] = []
    var processes: [ProcessInfo] = []
    var networkHistory: [NetworkSample] = []
    var connectionPhase: ConnectionPhase = .disconnected
    var hasConnectedOnce = false
    var keyPath: String?

    /// Keep enough samples to cover the visible window plus a small buffer
    /// for the Catmull-Rom spline context at edges.
    static let maxNetworkSamples = 65
    /// Duration of the visible time window in seconds.
    static let windowDuration: TimeInterval = 60

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        username: String,
        sshPort: Int = 22,
        agentPort: Int = 7654,
        hasKeyInstalled: Bool = false,
        keyPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.username = username
        self.sshPort = sshPort
        self.agentPort = agentPort
        self.hasKeyInstalled = hasKeyInstalled
        self.keyPath = keyPath
    }

    func appendNetworkSample(_ network: NetworkReport) {
        let sample = NetworkSample(
            download: network.physical.downloadBytesPerSec,
            upload: network.physical.uploadBytesPerSec,
            time: Date.timeIntervalSinceReferenceDate
        )
        networkHistory.append(sample)
        if networkHistory.count > Self.maxNetworkSamples {
            networkHistory.removeFirst(networkHistory.count - Self.maxNetworkSamples)
        }
    }
}
