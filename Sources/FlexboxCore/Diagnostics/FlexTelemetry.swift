//
//  FlexTelemetry.swift
//  FlexboxCore
//
//  Observability hooks (spec Pillar §Observabilitas). Without these you cannot
//  tell that the SDK is misbehaving on a user's device: how often the bundled
//  fallback layout was used, how long calculation takes, how many nodes were
//  reconciled per update.
//
//  The observer is a single process-wide weak reference. FlexboxCore never
//  retains it and never assumes one is installed.
//

import Foundation

/// Sink for FlexboxCore diagnostics. Implement in the host app to forward to
/// your logging / metrics stack. All callbacks may be invoked from any thread;
/// implementations must be thread-safe (hence `Sendable`).
public protocol FlexObserver: AnyObject, Sendable {
    /// A production-guarded operation was rejected instead of trapping.
    /// See `FlexPrecondition` and `YogaAssertCatalog`.
    func flexDidRejectOperation(_ operation: String, reason: String)

    /// A layout calculation pass completed.
    /// - Parameters:
    ///   - nodeCount: number of nodes in the calculated tree.
    ///   - durationNanos: wall-clock duration of the `YGNodeCalculateLayout` call.
    func flexDidCalculate(nodeCount: Int, durationNanos: UInt64)

    /// A payload could not be used and the bundled fallback layout was selected.
    func flexDidUseFallback(reason: String)

    /// A reconciliation pass produced `operationCount` minimal operations.
    func flexDidReconcile(operationCount: Int)
}

public extension FlexObserver {
    func flexDidRejectOperation(_ operation: String, reason: String) {}
    func flexDidCalculate(nodeCount: Int, durationNanos: UInt64) {}
    func flexDidUseFallback(reason: String) {}
    func flexDidReconcile(operationCount: Int) {}
}

/// Process-wide entry point for installing a `FlexObserver`.
///
/// Thread-safe. The reference is weak: the host owns the observer's lifetime.
public enum FlexTelemetry {
    private static let lock = NSLock()
    nonisolated(unsafe) private static weak var _observer: FlexObserver?

    /// The installed observer, if any.
    public static var observer: FlexObserver? {
        get { lock.withLock { _observer } }
        set { lock.withLock { _observer = newValue } }
    }

    // MARK: Internal emit helpers

    static func rejected(_ operation: String, _ reason: String) {
        observer?.flexDidRejectOperation(operation, reason: reason)
    }

    static func calculated(nodeCount: Int, durationNanos: UInt64) {
        observer?.flexDidCalculate(nodeCount: nodeCount, durationNanos: durationNanos)
    }

    static func usedFallback(_ reason: String) {
        observer?.flexDidUseFallback(reason: reason)
    }

    static func reconciled(operationCount: Int) {
        observer?.flexDidReconcile(operationCount: operationCount)
    }
}
