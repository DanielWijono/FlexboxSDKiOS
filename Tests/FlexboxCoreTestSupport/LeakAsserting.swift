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
        let baseline = LiveNodeCounter.current
        addTeardownBlock {
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
}
