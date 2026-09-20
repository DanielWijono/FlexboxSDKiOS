//
//  ScrollContentSizing.swift
//  FlexboxKit
//
//  The `UIScrollView.contentSize` for a scrollable node: the smallest size that
//  contains every direct child's laid-out frame, in the node's own content
//  coordinate space. With the recommended shape — one content wrapper under the
//  scroll node — that is just the wrapper's size.
//
//  Pure: `CGSize` is CoreGraphics (present on macOS) and `FlexNode` is
//  UIKit-free, so this compiles and is unit-tested under `swift test`.
//

import CoreGraphics
import FlexboxCore

enum ScrollContentSizing {

    /// The content extent of `scrollNode` after a `calculate(...)` pass: the
    /// maximum of `left + width` and of `top + height` over its direct children.
    /// `.zero` when it has none.
    ///
    /// The renderer writes this to the backing `FlexScrollBackingView.contentSize`
    /// once per pass; `contentOffset` is left untouched.
    static func contentSize(for scrollNode: FlexNode) -> CGSize {
        var width: Double = 0
        var height: Double = 0
        for child in scrollNode.children {
            let frame = child.layout
            width = max(width, frame.left + frame.width)
            height = max(height, frame.top + frame.height)
        }
        return CGSize(width: width, height: height)
    }
}
