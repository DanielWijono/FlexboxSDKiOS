//
//  FlexRenderObserver.swift
//  FlexboxKit
//
//  Per-host observability (spec Pillar §Observabilitas). FlexboxCore's
//  `FlexObserver` is a single process-wide slot with no per-tree attribution;
//  a `FlexRenderObserver` is attached to one `FlexHostView`, so an app with
//  many hosts can tell which screen a rejection or a slow pass came from.
//
//  All callbacks are invoked on the main thread (the renderer is main-thread
//  confined). Every method has a no-op default so conformers implement only
//  what they need.
//

import Foundation

/// Sink for one `FlexHostView`'s diagnostics.
public protocol FlexRenderObserver: AnyObject {

    /// A renderer operation was rejected instead of trapping (release builds),
    /// or is about to trap (debug builds). `operation` is a stable label from
    /// `KitAssertCatalog`; `reason` is human-readable detail.
    func flexHostDidRejectOperation(_ operation: String, reason: String)

    /// A layout pass completed on this host.
    /// - Parameters:
    ///   - nodeCount: nodes in the calculated tree.
    ///   - durationNanos: wall-clock time of the whole pass (calculate + apply).
    func flexHostDidLayout(nodeCount: Int, durationNanos: UInt64)

    /// A payload could not be used and the bundled fallback tree was rendered.
    func flexHostDidUseFallback(reason: String)

    /// The host rebuilt its node tree because a trait changed (display scale,
    /// content size category). `detail` names the trait.
    func flexHostDidRebuildForTraitChange(_ detail: String)
}

public extension FlexRenderObserver {
    func flexHostDidRejectOperation(_ operation: String, reason: String) {}
    func flexHostDidLayout(nodeCount: Int, durationNanos: UInt64) {}
    func flexHostDidUseFallback(reason: String) {}
    func flexHostDidRebuildForTraitChange(_ detail: String) {}
}
