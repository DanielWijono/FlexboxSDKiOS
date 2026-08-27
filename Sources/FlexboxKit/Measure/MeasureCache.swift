//
//  MeasureCache.swift
//  FlexboxKit
//
//  Per-pass memoization of leaf measurements (spec Artefak 3 §Inti "Cache
//  pengukuran"). Yoga can call a node's measure function several times in one
//  `calculate`, and `sizeThatFits` is not free; without a cache the cost grows
//  with hierarchy depth.
//
//  Cleared at the top of every layout / self-size pass (`beginPass`). A trait
//  change that invalidates all text metrics clears it out of band (`flushAll`).
//  Pure — no UIKit — so `swift test` covers it.
//

import Foundation
import FlexboxCore

/// Memo table from `(node id, width constraint, height constraint)` to the size
/// the leaf reported. `@unchecked Sendable`: guarded by a lock so the
/// `@Sendable` measure closure can hold it, though in practice every access is
/// on the main thread.
final class MeasureCache: @unchecked Sendable {

    struct Key: Hashable {
        let id: String
        let wTag: UInt8
        let wVal: Double
        let hTag: UInt8
        let hVal: Double

        init(id: String, width: FlexMeasureConstraint, height: FlexMeasureConstraint) {
            self.id = id
            (wTag, wVal) = Key.parts(width)
            (hTag, hVal) = Key.parts(height)
        }

        private static func parts(_ c: FlexMeasureConstraint) -> (UInt8, Double) {
            switch c {
            case .unconstrained: return (0, 0)
            case .exactly(let v): return (1, v)
            case .atMost(let v): return (2, v)
            }
        }
    }

    private let lock = NSLock()
    private var table: [Key: FlexSize] = [:]

    /// The cached size for `key`, if present in this pass.
    func lookup(_ key: Key) -> FlexSize? {
        lock.withLock { table[key] }
    }

    /// Stores `size` for `key` for the rest of this pass.
    func store(_ size: FlexSize, for key: Key) {
        lock.withLock { table[key] = size }
    }

    /// Drops everything. Call at the start of each layout / self-size pass.
    func beginPass() {
        lock.withLock { table.removeAll(keepingCapacity: true) }
    }

    /// Drops everything because an external factor (Dynamic Type) changed every
    /// measurement. Semantically distinct from `beginPass`; same effect.
    func flushAll() {
        lock.withLock { table.removeAll(keepingCapacity: false) }
    }

    /// Current entry count. For tests.
    var count: Int { lock.withLock { table.count } }
}
