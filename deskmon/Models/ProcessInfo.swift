import Foundation

struct ProcessInfo: Codable, Identifiable, Sendable {
    var pid: Int32
    var name: String
    var cpuPercent: Double
    var memoryMB: Double
    var memoryPercent: Double
    var command: String?
    var user: String?

    var id: Int32 { pid }
}
