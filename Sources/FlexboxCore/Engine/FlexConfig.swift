//
//  FlexConfig.swift
//  FlexboxCore
//
//  Per-tree Yoga configuration (spec Artefak 1 §"Config per pohon"). Never a
//  singleton: point-scale factor and errata belong to a tree, and since Yoga
//  3.0 the point-scale factor is honoured per node's config.
//
//  `pointScaleFactor` must come from `traitCollection.displayScale`, NOT
//  `UIScreen.main` — Split View, Slide Over and Stage Manager make the value
//  differ between scenes and change at runtime. FlexboxCore takes a plain
//  `Double`; FlexboxKit supplies the trait-derived value.
//

/// Configuration shared by every node in one tree. One `YGConfig` is owned here
/// and freed on `deinit`.
public final class FlexConfig {
    let handle: YogaConfigHandle

    /// Rounding grid for layout results. `1` = whole points, `2` = half points,
    /// `3` ≈ @3x device pixels. `0` disables rounding.
    public let pointScaleFactor: Double

    /// Legacy-compatibility level. Set explicitly; documented per spec.
    public let errata: FlexErrata

    public init(pointScaleFactor: Double = 1.0, errata: FlexErrata = .none) {
        self.pointScaleFactor = pointScaleFactor
        self.errata = errata
        self.handle = yoga_configNew()
        yoga_configSetPointScaleFactor(handle, pointScaleFactor)
        yoga_configSetErrata(handle, errata)
    }

    /// A headless default (scale `1.0`, no errata). Real apps pass a config
    /// built from the current trait collection.
    public static var `default`: FlexConfig { FlexConfig() }

    deinit {
        yoga_configFree(handle)
    }
}
