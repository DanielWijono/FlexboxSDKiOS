//
//  FlexConfigFactory.swift
//  FlexboxKit
//
//  Builds a `FlexConfig` for a tree from the current display scale.
//
//  The scale MUST come from a view's `traitCollection.displayScale`, never
//  `UIScreen.main`: Split View, Slide Over and Stage Manager make the value
//  differ per scene and change at runtime (spec Artefak 1 §"Config per pohon",
//  ARCHITECTURE.md). CI greps `Sources/` for `UIScreen.main`.
//
//  `FlexConfig` is immutable and per-tree in Core, so a scale change means a new
//  config and a rebound node tree — the host does that in `traitCollectionDidChange`.
//

import CoreGraphics
import FlexboxCore

enum FlexConfigFactory {

    /// A config whose `pointScaleFactor` is `displayScale` (1 = points, 2 = @2x,
    /// 3 = @3x). A non-positive scale falls back to `1` rather than disabling
    /// rounding.
    static func makeConfig(displayScale: CGFloat, errata: FlexErrata) -> FlexConfig {
        let scale = displayScale > 0 ? Double(displayScale) : 1.0
        return FlexConfig(pointScaleFactor: scale, errata: errata)
    }
}

#if canImport(UIKit)
import UIKit

extension FlexConfigFactory {

    /// A config built from `view`'s current trait collection.
    @MainActor
    static func makeConfig(for view: UIView, errata: FlexErrata) -> FlexConfig {
        makeConfig(displayScale: view.traitCollection.displayScale, errata: errata)
    }
}
#endif
