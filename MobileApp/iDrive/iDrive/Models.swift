import Foundation

// Simple Codable models matching backend JSON
struct Ride: Codable, Identifiable {
    var id: String
    var status: String
    var driverId: String?
    var payload: [String: CodableValue]?
    var createdAt: Int?
    var locations: [LocationPointModel]?
}

struct LocationPointModel: Codable {
    var lat: Double
    var lng: Double
    var ts: Int?
}

// Helper to decode heterogeneous payload dictionary
enum CodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: CodableValue])
    case array([CodableValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode([String: CodableValue].self) { self = .object(v); return }
        if let v = try? c.decode([CodableValue].self) { self = .array(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        }
    }
}

