//
//  FlexNode.swift
//  FlexboxCore
//
//  A Swift wrapper around exactly one live Yoga node. Trees of `FlexNode` are
//  usable headless — no UIKit required.
//
//  Ownership contract (spec Artefak 1 §"Kontrak kepemilikan"), enforced here:
//    • a parent holds a STRONG reference to each child (`children`)
//    • a child holds a WEAK reference to its parent (`parent`) — reversing this
//      direction creates a retain cycle
//    • a `FlexNode` owns its `YGNodeRef` exclusively and uniquely
//    • stored closures must not strongly capture a node or a view
//
//  Concurrency (spec §Konkurensi): no `@MainActor`. `FlexNode` is a `final
//  class` with non-`Sendable` stored state, so Swift 6 forbids sharing it
//  across concurrency domains — the tree is thread-confined by construction.
//

import Foundation

public final class FlexNode {
    /// The uniquely-owned Yoga node. Never handed out raw.
    let handle: YogaNodeHandle

    /// Configuration for the whole tree this node belongs to.
    public let config: FlexConfig

    /// Weak, per the ownership contract. `nil` for a root or a detached subtree.
    public internal(set) weak var parent: FlexNode?

    /// Strong. The parent owns its children; a tree stays alive without views.
    public internal(set) var children: [FlexNode] = []

    /// Leaf measurement. Set via `setMeasure(_:)`; only valid on a leaf.
    var measureFunction: FlexMeasureFunction?

    /// Engine-level "this node was dirtied" hook (spec §Invalidasi). Edge-
    /// triggered and a *complementary* signal — not the only source of
    /// invalidation. Must not strongly capture a node or view.
    public var onDirtied: (@Sendable () -> Void)? {
        didSet { yoga_setDirtiedEnabled(handle, onDirtied != nil) }
    }

    public init(config: FlexConfig = .default) {
        self.config = config
        self.handle = yoga_nodeNew(config: config.handle)

        // Install an UNRETAINED back-pointer so the measure / dirtied trampolines
        // can recover `self`. `passRetained` is forbidden — it would leak every
        // node. The pointer is cleared in `deinit` before the node is freed.
        yoga_setContext(handle, Unmanaged.passUnretained(self).toOpaque())

        #if DEBUG
        LiveNodeCounter.increment()
        #endif
    }

    // MARK: Teardown
    //
    // Order is strict and must not be reordered (spec §"Aturan pembongkaran"):
    //   1. clear measure function, dirtied hook, and context
    //   2. detach children still parented at the Yoga level, then detach self
    //      from its own Yoga owner
    //   3. free THIS node only — `YGNodeFreeRecursive` is forbidden
    //
    // Step 2's child sweep matters: Swift runs this body before releasing the
    // `children` array, so without it each child's own `deinit` would read a
    // freed owner pointer (use-after-free) a moment later.

    deinit {
        yoga_setMeasureEnabled(handle, false)
        yoga_setDirtiedEnabled(handle, false)
        yoga_clearContext(handle)

        for child in children where yoga_owner(of: child.handle) == handle {
            yoga_removeChild(child.handle, from: handle)
        }
        if let owner = yoga_owner(of: handle) {
            yoga_removeChild(handle, from: owner)
        }

        yoga_nodeFree(handle)

        #if DEBUG
        LiveNodeCounter.decrement()
        #endif
    }

    // MARK: Traversal

    /// Direct children count. Equals `YGNodeGetChildCount` after every mutation
    /// (checked by the DEBUG invariant).
    public var childCount: Int { children.count }

    /// Total nodes in the subtree rooted at this node, inclusive.
    public var nodeCount: Int {
        1 + children.reduce(0) { $0 + $1.nodeCount }
    }

    /// `true` once this node's config has produced at least one layout pass and
    /// nothing has dirtied it since.
    public var isDirty: Bool { yoga_isDirty(handle) }

    // MARK: DEBUG invariant

    /// Spec §"Gerbang kebocoran": the Swift child list and the Yoga child list
    /// must agree after every structural mutation and every layout pass. This is
    /// the only automatic check for "subview detached without its node".
    func assertChildInvariant(_ function: StaticString = #function) {
        #if DEBUG
        let swiftCount = children.count
        let yogaCount = yoga_childCount(handle)
        assert(
            swiftCount == yogaCount,
            "FlexNode child-count invariant violated after \(function): "
                + "swift=\(swiftCount) yoga=\(yogaCount)"
        )
        #endif
    }
}

// MARK: - Engine callbacks

extension FlexNode: YogaMeasuring {
    func yogaMeasure(width: FlexMeasureConstraint, height: FlexMeasureConstraint) -> FlexSize {
        measureFunction?(width, height) ?? .zero
    }
}

extension FlexNode: YogaDirtyObserving {
    func yogaDidDirty() {
        onDirtied?()
    }
}
