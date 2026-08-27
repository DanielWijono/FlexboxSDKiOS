//
//  LayoutPayload.swift
//  FlexboxCore
//
//  The envelope a backend sends. The schema version travels WITH the data
//  (spec §"Validasi payload") so an app can tell whether it understands the
//  layout before trying to use it.
//

public struct LayoutPayload: Codable, Equatable, Sendable {
    /// Schema version this payload was authored against. Required.
    public var schemaVersion: Int

    /// The root of the layout.
    public var root: LayoutTree

    public init(schemaVersion: Int = LayoutSchema.current, root: LayoutTree) {
        self.schemaVersion = schemaVersion
        self.root = root
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, root
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // A missing version is treated as version 0 → unsupported, so an
        // un-versioned payload falls back rather than being guessed at.
        self.schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        self.root = try c.decode(LayoutTree.self, forKey: .root)
    }
}
