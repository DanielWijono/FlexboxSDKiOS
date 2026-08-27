//
//  JSONValue.swift
//  FlexboxCore
//
//  A closed representation of arbitrary JSON, used for leaf `props` (a label's
//  text, an image name, parameters for a custom view).
//
//  This is the App Store boundary encoded in the type system (spec Pillar
//  §"Batas terhadap kebijakan App Store"): `props` can carry DATA — strings,
//  numbers, bools, nested arrays/objects — and there is no case that can carry
//  code, an expression to evaluate, or a navigation instruction.
//

public enum JSONValue: Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Value is not representable as JSON"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

/// A bag of leaf parameters. Ordered-insensitive; compared by content.
public typealias PropBag = [String: JSONValue]

extension JSONValue {
    /// Number of scalar leaves in this value — used by depth / size limits.
    var scalarCount: Int {
        switch self {
        case .string, .number, .bool, .null:
            return 1
        case .array(let items):
            return items.reduce(0) { $0 + $1.scalarCount }
        case .object(let members):
            return members.values.reduce(0) { $0 + $1.scalarCount }
        }
    }
}
