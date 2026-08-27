//
//  LayoutLimits.swift
//  FlexboxCore
//
//  Bounds enforced while decoding / validating a payload (spec §"Validasi
//  payload": "Batasi kedalaman pohon dan jumlah node saat parsing"). A payload
//  that exceeds any bound is rejected and the caller falls back.
//
//  Defaults are deliberately generous for real screens but far below what would
//  let a hostile payload exhaust memory or stack.
//

public struct LayoutLimits: Equatable, Sendable {
    /// Maximum tree depth (a single node is depth 1).
    public var maxDepth: Int
    /// Maximum total node count.
    public var maxNodes: Int
    /// Maximum scalar leaves across all `props` bags in the tree.
    public var maxPropScalars: Int
    /// Maximum length of any single `id`.
    public var maxIDLength: Int

    public init(
        maxDepth: Int = 64,
        maxNodes: Int = 2_000,
        maxPropScalars: Int = 10_000,
        maxIDLength: Int = 256
    ) {
        self.maxDepth = maxDepth
        self.maxNodes = maxNodes
        self.maxPropScalars = maxPropScalars
        self.maxIDLength = maxIDLength
    }

    public static let `default` = LayoutLimits()
}
