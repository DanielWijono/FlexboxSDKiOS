//
//  FlexPrecondition.swift
//  FlexboxCore
//
//  Spec Pillar §"Tidak boleh ada assert fatal di build release".
//
//  Yoga aborts the process on a number of misuse paths (inserting a child that
//  already has an owner, marking a measure-less node dirty, attaching a measure
//  function to a non-leaf, ...). This SDK layers network-sourced payloads on top
//  of Yoga, so any of those can be reached from bad JSON. A layout file must
//  never be able to crash the app.
//
//  Every such path is fronted by `flexRequire`:
//    - DEBUG  : `assertionFailure` — trap, so tests and development catch misuse.
//    - RELEASE: log via `FlexTelemetry`, return `false`, and let the caller
//               abort the operation and keep the last valid state.
//
//  The RELEASE behaviour is exercised in DEBUG tests by flipping
//  `FlexPrecondition.assertsAreFatal` — see AssertCatalogTests.
//
//  The full list of guarded paths lives in `YogaAssertCatalog`.
//

public enum FlexPrecondition {
    /// When `true` (the default) a failed precondition traps in DEBUG. Set to
    /// `false` around code that deliberately drives a guarded path to verify the
    /// reject-and-continue behaviour. No effect in release builds.
    nonisolated(unsafe) public static var assertsAreFatal = true
}

/// Evaluates a production precondition.
///
/// - Returns: `true` if `condition` holds and the caller may proceed; `false` if
///   the caller must abort the current operation without mutating state.
@discardableResult
@inline(__always)
func flexRequire(
    _ condition: @autoclosure () -> Bool,
    operation: StaticString,
    _ reason: @autoclosure () -> String,
    file: StaticString = #fileID,
    line: UInt = #line
) -> Bool {
    if condition() { return true }

    let op = String(describing: operation)
    let why = reason()

    FlexTelemetry.rejected(op, why)

    #if DEBUG
    if FlexPrecondition.assertsAreFatal {
        assertionFailure("FlexboxCore rejected \(op): \(why)", file: file, line: line)
    }
    #endif

    return false
}
