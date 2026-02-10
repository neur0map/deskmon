import Foundation

struct NetworkSample: Sendable {
    let download: Double
    let upload: Double
}

enum ConnectionPhase: Sendable {
    case connecting   // No data yet
    case syncing      // Got snapshot, establishing live stream
    case live         // SSE delivering events (or timed into live)
}

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
    var processes: [ProcessInfo] = []
    var services: [ServiceInfo] = []
    var networkHistory: [NetworkSample] = []
    /// Snapshot the sparkline actually reads — updated every `networkBatchSize` samples.
    var displayNetworkHistory: [NetworkSample] = []
    var connectionPhase: ConnectionPhase = .connecting
    var hasConnectedOnce = false

    /// Incremented every batch; drives the sparkline scroll animation.
    var networkBatchID: UInt64 = 0

    /// Timestamp of the last services SSE event; drives the refresh countdown.
    var lastServicesUpdate: Date?

    /// Raw buffer holds visible + one batch of headroom for the scroll animation.
    static let maxNetworkSamples = 65
    /// How many samples are visible in the graph at once.
    static let visibleNetworkSamples = 60
    /// How many 1-second ticks to collect before flushing to the display buffer.
    static let networkBatchSize = 5

    private var samplesSinceBatch: Int = 0

    init(id: UUID = UUID(), name: String, host: String, port: Int = 7654, token: String = "") {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.token = token
    }

    func appendNetworkSample(_ network: NetworkStats) {
        let sample = NetworkSample(download: network.downloadBytesPerSec, upload: network.uploadBytesPerSec)
        networkHistory.append(sample)
        if networkHistory.count > Self.maxNetworkSamples {
            networkHistory.removeFirst(networkHistory.count - Self.maxNetworkSamples)
        }

        samplesSinceBatch += 1

        if samplesSinceBatch >= Self.networkBatchSize {
            samplesSinceBatch = 0
            displayNetworkHistory = networkHistory
            networkBatchID &+= 1
        }
    }
}
