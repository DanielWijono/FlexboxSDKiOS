//
//  LayoutTree+Flatten.swift
//  FlexboxKit
//
//  A pre-order flattening of a `LayoutTree`, used by the renderer to compare two
//  trees node-by-node (e.g. `FlexHostView.contentKindDiffers`). Pure — no UIKit,
//  so it also compiles and is testable under `swift test` on macOS.
//

import FlexboxCore

extension LayoutTree {
    /// Every node in the subtree, pre-order (self first, then each child's
    /// flattening in order).
    func flexFlattened() -> [LayoutTree] {
        [self] + children.flatMap { $0.flexFlattened() }
    }
}
