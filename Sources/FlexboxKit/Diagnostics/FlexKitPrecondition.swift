//
//  FlexKitPrecondition.swift
//  FlexboxKit
//
//  The renderer's release-safe guard, mirroring FlexboxCore's `flexRequire`
//  (which is `internal` to Core and not callable here). Same rule as the spec
//  Pillar §"Tidak boleh ada assert fatal di build release":
//    • DEBUG  — trap, so a misuse is caught in development
//    • RELEASE — report, return `false`, and let the caller no-op from its last
//      valid state; never kill the process
//
//  `KitAssertCatalog` lists every call site as data.
//

import Foundation

/// Controls whether a failed `flexKitRequire` traps in DEBUG builds. Tests set
/// this to `false` to exercise the reject-and-continue path. No effect in
/// release builds, which never trap.
public enum FlexKitPrecondition {
    nonisolated(unsafe) public static var assertsAreFatal = true
}

/// Checks `condition`. On failure: reports to `observer` and to the process-wide
/// `FlexTelemetry.observer`, then either traps (DEBUG, when
/// `FlexKitPrecondition.assertsAreFatal`) or returns `false` (RELEASE, or when
/// asserts are disabled) so the caller can abort the operation without mutating.
///
/// - Returns: `true` to proceed, `false` to abort.
@discardableResult
@inline(__always)
func flexKitRequire(
    _ condition: @autoclosure () -> Bool,
    operation: StaticString,
    _ reason: @autoclosure () -> String,
    observer: FlexRenderObserver? = nil,
    file: StaticString = #fileID,
    line: UInt = #line
) -> Bool {
    if condition() { return true }

    let op = String(describing: operation)
    let detail = reason()
    observer?.flexHostDidRejectOperation(op, reason: detail)
    FlexboxCoreBridge.reportRejected(operation: op, reason: detail)

    #if DEBUG
    if FlexKitPrecondition.assertsAreFatal {
        assertionFailure("[FlexboxKit] \(op) rejected: \(detail)", file: file, line: line)
    }
    #endif
    return false
}
