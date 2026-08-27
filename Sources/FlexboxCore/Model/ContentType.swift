//
//  ContentType.swift
//  FlexboxCore
//
//  What a node renders. Containers lay out children; the others are leaves that
//  measure their own content. `custom` names a factory the host app registers
//  in the view registry (spec Artefak 3).
//
//  JSON form is a bare string: "container", "text", "image", or any other
//  string, which is taken as `custom("<that>")`.
//

public enum ContentType: Equatable, Sendable {
    case container
    case text
    case image
    case custom(String)

    /// Leaves measure their own content and must not have children.
    public var isLeaf: Bool {
        switch self {
        case .container: return false
        case .text, .image, .custom: return true
        }
    }
}

extension ContentType: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "container": self = .container
        case "text": self = .text
        case "image": self = .image
        case "": throw DecodingError.dataCorruptedError(
            in: try decoder.singleValueContainer(),
            debugDescription: "ContentType string must not be empty"
        )
        default: self = .custom(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .container: try container.encode("container")
        case .text: try container.encode("text")
        case .image: try container.encode("image")
        case .custom(let name): try container.encode(name)
        }
    }
}
