//
//  LayoutSchema.swift
//  FlexboxCore
//
//  The public contract version. Defined HERE, not in the app (spec Artefak 2
//  §"Skema dan serialisasi"): version and unknown-key policy are part of the
//  SDK's public surface.
//
//  Version history — see SCHEMA.md for the authoritative changelog:
//    1  initial: FlexStyle, LayoutTree, FlexDimension (points / "n%" / "auto"),
//       Edges shorthand + object, ContentType, props (JSONValue).
//

public enum LayoutSchema {
    /// Highest schema version this build understands.
    public static let current = 1

    /// Lowest schema version this build still accepts.
    public static let minimumSupported = 1

    /// Whether this build can decode a payload authored against `version`.
    public static func supports(_ version: Int) -> Bool {
        (minimumSupported ... current).contains(version)
    }
}
