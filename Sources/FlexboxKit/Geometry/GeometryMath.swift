//
//  GeometryMath.swift
//  FlexboxKit
//
//  Pure conversion from a Yoga layout result to the `(bounds.size, center)` pair
//  a `UIView` needs. No UIKit — `CGSize` / `CGPoint` come from CoreGraphics,
//  which is present on macOS too, so this file compiles and is unit-tested under
//  `swift test`.
//
//  Rules (spec Artefak 3 §Inti "Geometri"):
//    • the size is Yoga's width/height verbatim — NO rounding on the Swift side,
//      Yoga already snapped to the config's `pointScaleFactor`
//    • `center` places the box's origin at Yoga's (left, top) in the parent's
//      coordinate space, accounting for the layer's anchor point
//    • the caller preserves the view's existing `bounds.origin` — overwriting it
//      resets `UIScrollView.contentOffset`
//

import CoreGraphics

/// The `bounds.size` for a node laid out to `width` x `height` points.
@inline(__always)
func flexBoundsSize(width: Double, height: Double) -> CGSize {
    CGSize(width: CGFloat(width), height: CGFloat(height))
}

/// The `center` (in the parent view's coordinate space) that puts a box of
/// `width` x `height` with its top-left corner at (`left`, `top`), given the
/// backing layer's `anchorPoint` (default `(0.5, 0.5)`).
@inline(__always)
func flexCenter(
    left: Double,
    top: Double,
    width: Double,
    height: Double,
    anchorPoint: CGPoint
) -> CGPoint {
    CGPoint(
        x: CGFloat(left) + CGFloat(width) * anchorPoint.x,
        y: CGFloat(top) + CGFloat(height) * anchorPoint.y
    )
}
