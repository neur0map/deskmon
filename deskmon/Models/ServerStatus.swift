import SwiftUI

enum ServerStatus: String, Codable, CaseIterable {
    case healthy
    case warning
    case critical
    case offline

    var color: Color {
        switch self {
        case .healthy: Theme.healthy
        case .warning: Theme.warning
        case .critical: Theme.critical
        case .offline: .secondary
        }
    }

    var label: String {
        switch self {
        case .healthy: "Healthy"
        case .warning: "Warning"
        case .critical: "Critical"
        case .offline: "Offline"
        }
    }

    var systemImage: String {
        switch self {
        case .healthy: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        case .offline: "wifi.slash"
        }
    }
}
