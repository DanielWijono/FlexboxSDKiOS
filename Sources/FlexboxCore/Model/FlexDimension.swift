//
//  FlexDimension.swift
//  FlexboxCore
//
//  A length in a style: points, a percentage, or "auto".
//
//  Serialization (spec Artefak 2 §"Skema dan serialisasi"):
//    • points     → a JSON number:  12  /  12.5
//    • percentage → a JSON string ending in "%":  "50%"
//    • auto       → the JSON string "auto"
//
//  There is no encoding for "undefined" — that is the ABSENCE of the key.
//  `YGUndefined` is NaN and NaN has no JSON form, so a missing value round-trips
//  to `nil`, never to a number.
//

public enum FlexDimension: Equatable, Sendable {
    case points(Double)
    case percent(Double)
    case auto
}

extension FlexDimension: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let number = try? container.decode(Double.self) {
            guard number.isFinite else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "FlexDimension point value must be finite, got \(number)"
                )
            }
            self = .points(number)
            return
        }

        let string = try container.decode(String.self)
        if string == "auto" {
            self = .auto
            return
        }
        if string.hasSuffix("%"), let value = Double(string.dropLast()), value.isFinite {
            self = .percent(value)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: #"FlexDimension string must be "auto" or "<number>%", got "\#(string)""#
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .points(let value):
            try container.encode(value)
        case .percent(let value):
            try container.encode("\(formatted(value))%")
        case .auto:
            try container.encode("auto")
        }
    }

    private func formatted(_ value: Double) -> String {
        // Keep "50%" rather than "50.0%" while preserving real fractions.
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(value)
    }
}

public extension FlexDimension {
    /// Convenience for integral point values in Swift call sites.
    static func points(_ value: Int) -> FlexDimension { .points(Double(value)) }
}
