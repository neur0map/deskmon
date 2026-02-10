import Foundation

struct StatItem: Codable, Sendable, Identifiable {
    let label: String
    let value: String
    let type: String // "number", "percent", "status", "text"

    var id: String { label }
}

struct ServiceInfo: Codable, Sendable, Identifiable {
    let pluginId: String
    let name: String
    let icon: String
    let status: String // "running", "stopped", "error"
    let summary: [StatItem]
    let stats: [String: AnyCodableValue]
    let error: String?

    var id: String { pluginId }

    var isRunning: Bool { status == "running" }
}

// MARK: - AnyCodableValue (type-erased JSON value)

enum AnyCodableValue: Codable, Sendable {
    case string(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int64.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if container.decodeNil() {
            self = .null
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var intValue: Int64? {
        switch self {
        case .int(let v): return v
        case .double(let v): return Int64(v)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }
}
