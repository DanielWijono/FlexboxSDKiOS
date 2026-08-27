//
//  FlexNode+Layout.swift
//  FlexboxCore
//
//  Calculation and result read-back, plus leaf measurement wiring.
//

import Foundation

extension FlexNode {

    /// Runs a layout pass over this subtree.
    ///
    /// Lifetime contract (spec §"Masa hidup selama kalkulasi"): the calculation
    /// BORROWS the tree. The caller must keep this root alive for the whole
    /// call — dropping it mid-pass trades a leak for a use-after-free.
    ///
    /// Pass `NaN`-free finite values, or `.nan` explicitly for "unconstrained".
    public func calculate(
        availableWidth: Double,
        availableHeight: Double,
        direction: FlexWritingDirection = .ltr
    ) {
        let start = DispatchTime.now().uptimeNanoseconds
        yoga_calculate(
            handle,
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            direction: direction
        )
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        FlexTelemetry.calculated(nodeCount: nodeCount, durationNanos: elapsed)
        assertChildInvariant()
    }

    /// The most recent layout result for this node, relative to its parent, in
    /// points. Unrounded. Valid only after a `calculate(...)` pass on an
    /// ancestor (or this node).
    public var layout: FlexLayoutResult {
        yoga_layout(handle)
    }

    // MARK: Measurement

    /// Installs (or clears, with `nil`) a leaf measure function.
    ///
    /// Rejected if the node has children — a measured node must be a leaf
    /// (mirrors a Yoga fatal assert).
    public func setMeasure(_ measure: FlexMeasureFunction?) {
        if measure != nil {
            guard flexRequire(
                children.isEmpty,
                operation: "FlexNode.setMeasure",
                "a measure function is only valid on a leaf node"
            ) else { return }
        }
        measureFunction = measure
        yoga_setMeasureEnabled(handle, measure != nil)
    }

    /// Marks this leaf dirty because its external content (text, image, ...)
    /// changed. Yoga cannot see that on its own (spec §Invalidasi).
    ///
    /// Rejected if the node has no measure function (a Yoga fatal assert).
    public func markContentDirty() {
        guard flexRequire(
            yoga_hasMeasureFunc(handle),
            operation: "FlexNode.markContentDirty",
            "only a leaf with a measure function can be marked content-dirty"
        ) else { return }
        yoga_markDirty(handle)
    }
}
