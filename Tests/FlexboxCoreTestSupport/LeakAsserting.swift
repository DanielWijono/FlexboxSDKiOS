//
//  LeakAsserting.swift
//  FlexboxCoreTestSupport
//
//  Shared teardown gates for the leak checks (spec §"Gerbang kebocoran").
//  Every engine test funnels through these so the guarantees are uniform.
//

import XCTest
@testable import FlexboxCore

/// Holds a weak reference across the concurrency boundary of `addTeardownBlock`
/// without sending the referent itself.
public final class WeakBox: @unchecked Sendable {
    public weak var value: AnyObject?
    public init(_ value: AnyObject?) { self.value = value }
}

extension XCTestCase {

    /// Asserts, at test teardown, that `object` has been deallocated.
    public func assertDeallocated(
        _ object: AnyObject,
        _ label: String = "object",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let box = WeakBox(object)
        addTeardownBlock {
            XCTAssertNil(box.value, "\(label) was not deallocated — leak", file: file, line: line)
        }
    }

    /// Asserts, at test teardown, that the DEBUG live-node census is back to the
    /// value it had when this was called (normally zero).
    public func assertLiveNodeCountReturnsToBaseline(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        #if DEBUG
        // UIKit may release a test's window (and the nodes it owns) on a later
        // run-loop turn — observed on iPad. Drain before both samples so the
        // census counts what is actually retained, not what is merely pending.
        Self.drainPendingReleases()
        let baseline = LiveNodeCounter.current
        addTeardownBlock {
            Self.drainPendingReleases(until: { LiveNodeCounter.current <= baseline })
            XCTAssertEqual(
                LiveNodeCounter.current,
                baseline,
                "live FlexNode count did not return to \(baseline) — nodes leaked",
                file: file,
                line: line
            )
        }
        #endif
    }

    /// Spins the main run loop in short turns until `done` holds or ~0.5 s pass
    /// (one turn when `done` is nil). A real leak still fails: the census never
    /// reaches the baseline. Off the main thread this is a no-op.
    private static func drainPendingReleases(until done: (() -> Bool)? = nil) {
        guard Thread.isMainThread else { return }
        let deadline = Date().addingTimeInterval(0.5)
        repeat {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        } while !(done?() ?? true) && Date() < deadline
    }
}
