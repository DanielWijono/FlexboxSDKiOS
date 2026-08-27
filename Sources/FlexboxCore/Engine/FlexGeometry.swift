//
//  FlexGeometry.swift
//  FlexboxCore
//
//  Swift-native geometry and engine-level enums. None of these expose a `YG*`
//  type; the mapping to Yoga lives in `YogaInterop.swift`.
//

/// Result of a layout pass for a single node, in points, relative to its parent.
///
/// Values are raw Yoga output — not rounded. Pixel rounding, if any, is the
/// renderer's job (spec Artefak 3: "Jangan membulatkan di sisi Swift").
public struct FlexLayoutResult: Equatable, Sendable {
    public var left: Double
    public var top: Double
    public var width: Double
    public var height: Double

    public init(left: Double, top: Double, width: Double, height: Double) {
        self.left = left
        self.top = top
        self.width = width
        self.height = height
    }

    public static let zero = FlexLayoutResult(left: 0, top: 0, width: 0, height: 0)
}

/// Writing direction passed to a layout pass.
public enum FlexWritingDirection: String, Sendable, CaseIterable {
    case inherit
    case ltr
    case rtl
}

/// The constraint mode Yoga hands to a measure function on one axis.
///
/// Mapping these all to "at most" is a common and wrong shortcut
/// (spec Artefak 3 §Inti).
public enum FlexMeasureConstraint: Sendable, Equatable {
    /// No constraint on this axis — measure at natural size.
    case unconstrained
    /// Must return exactly this extent.
    case exactly(Double)
    /// May return up to this extent.
    case atMost(Double)
}

/// A measured size returned by a leaf's measure function.
public struct FlexSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = FlexSize(width: 0, height: 0)
}

/// Yoga errata compatibility level for a config. Set explicitly and documented
/// per spec Artefak 1 §"Config per pohon".
public enum FlexErrata: Sendable, Equatable {
    /// No legacy quirks. The default for new code.
    case none
    /// All errata enabled — closest to Yoga 1.x behaviour.
    case classic
    /// Every current and future erratum. Use only to match a legacy renderer.
    case all
}
