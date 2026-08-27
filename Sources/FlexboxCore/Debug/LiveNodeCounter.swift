//
//  LiveNodeCounter.swift
//  FlexboxCore
//
//  DEBUG-only census of live `FlexNode` instances (spec §"Gerbang kebocoran").
//  Every test asserts this returns to zero on teardown; the child/child-count
//  invariant and the weak-reference teardown checks build on top of it.
//
//  Compiled out entirely in release builds.
//

#if DEBUG
import Foundation

enum LiveNodeCounter {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _count = 0
    nonisolated(unsafe) private static var _peak = 0

    static func increment() {
        lock.withLock {
            _count += 1
            if _count > _peak { _peak = _count }
        }
    }

    static func decrement() {
        lock.withLock { _count -= 1 }
    }

    /// Number of `FlexNode` instances currently alive.
    static var current: Int {
        lock.withLock { _count }
    }

    /// Highest `current` observed since the last `resetPeak()`.
    static var peak: Int {
        lock.withLock { _peak }
    }

    static func resetPeak() {
        lock.withLock { _peak = _count }
    }
}
#endif
