//
//  MeasureReentrancyGuard.swift
//  FlexboxKit
//
//  Breaks the `intrinsicContentSize → calculate → measure → sizeThatFits →
//  intrinsicContentSize` recursion (spec Artefak 3 §Inti "penjaga reentrancy").
//
//  A `FlexHostView` wraps each of its own layout / self-size passes in
//  `enter()` / `leave()`. While a pass is active:
//    • `flexScheduleRelayout()` is a no-op — the running pass will settle it
//    • the self-size hooks (`sizeThatFits`, `intrinsicContentSize`) return the
//      last size they produced instead of starting a nested pass
//
//  Pure — no UIKit.
//

import Foundation

/// Non-negative depth counter for host layout passes. `@unchecked Sendable`:
/// lock-guarded; accessed on the main thread in practice.
final class MeasureReentrancyGuard: @unchecked Sendable {

    private let lock = NSLock()
    private var depth = 0

    /// Enters a pass. Returns `true` if this is the outermost pass (safe to run),
    /// `false` if a pass is already running (caller should use a cached result).
    @discardableResult
    func enter() -> Bool {
        lock.withLock {
            depth += 1
            #if DEBUG
            assert(depth <= 2, "FlexboxKit: layout pass re-entered \(depth) deep")
            #endif
            return depth == 1
        }
    }

    /// Leaves a pass.
    func leave() {
        lock.withLock {
            if depth > 0 { depth -= 1 }
        }
    }

    /// `true` while any pass is running.
    var isActive: Bool { lock.withLock { depth > 0 } }
}
