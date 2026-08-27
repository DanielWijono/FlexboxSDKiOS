//
//  RecordingRenderObserver.swift
//  FlexboxKitTestSupport
//
//  A `FlexRenderObserver` that records every callback, for assertions.
//

#if canImport(UIKit)
import Foundation
import FlexboxKit

public final class RecordingRenderObserver: FlexRenderObserver {

    public struct Rejection: Equatable {
        public let operation: String
        public let reason: String
    }
    public struct LayoutPass: Equatable {
        public let nodeCount: Int
        public let durationNanos: UInt64
    }

    public private(set) var rejections: [Rejection] = []
    public private(set) var layoutPasses: [LayoutPass] = []
    public private(set) var fallbackReasons: [String] = []
    public private(set) var traitRebuilds: [String] = []

    public init() {}

    public func flexHostDidRejectOperation(_ operation: String, reason: String) {
        rejections.append(Rejection(operation: operation, reason: reason))
    }

    public func flexHostDidLayout(nodeCount: Int, durationNanos: UInt64) {
        layoutPasses.append(LayoutPass(nodeCount: nodeCount, durationNanos: durationNanos))
    }

    public func flexHostDidUseFallback(reason: String) {
        fallbackReasons.append(reason)
    }

    public func flexHostDidRebuildForTraitChange(_ detail: String) {
        traitRebuilds.append(detail)
    }

    public var didReject: Bool { !rejections.isEmpty }
}
#endif
