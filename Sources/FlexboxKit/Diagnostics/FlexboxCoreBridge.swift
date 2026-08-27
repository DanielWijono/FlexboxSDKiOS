//
//  FlexboxCoreBridge.swift
//  FlexboxKit
//
//  A thin forwarder onto FlexboxCore's process-wide `FlexTelemetry` observer.
//  Core's internal emit helpers (`FlexTelemetry.rejected`, `.calculated`, ...)
//  are not visible here, but the public `FlexTelemetry.observer` slot is, so a
//  renderer-side event still reaches a host that installed a `FlexObserver`.
//

import Foundation
import FlexboxCore

enum FlexboxCoreBridge {

    /// Forward a renderer rejection to any installed `FlexObserver`.
    static func reportRejected(operation: String, reason: String) {
        FlexTelemetry.observer?.flexDidRejectOperation(operation, reason: reason)
    }

    /// Forward a completed renderer layout pass to any installed `FlexObserver`.
    /// (A `FlexNode.calculate` pass already reports itself from Core; this covers
    /// the whole host pass including view-geometry application.)
    static func reportCalculated(nodeCount: Int, durationNanos: UInt64) {
        FlexTelemetry.observer?.flexDidCalculate(nodeCount: nodeCount, durationNanos: durationNanos)
    }

    /// Forward a fallback selection to any installed `FlexObserver`.
    static func reportUsedFallback(reason: String) {
        FlexTelemetry.observer?.flexDidUseFallback(reason: reason)
    }
}
