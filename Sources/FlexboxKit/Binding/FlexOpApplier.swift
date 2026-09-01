//
//  FlexOpApplier.swift
//  FlexboxKit
//
//  The view-side twin of FlexboxCore's `OpApplier`: it walks a `[LayoutOp]` from
//  `Reconciler` and mutates the live `FlexNode` tree and the `UIView` tree in
//  lockstep, so one `update(to:)` touches only what actually changed.
//
//  Contract (spec Artefak 3 §"Rekonsiliasi ke view", ARCHITECTURE.md):
//    • Removal is mandatory and total — a removed node's `UIView` leaves the
//      hierarchy AND its `FlexNode` is detached and dropped from the index, or
//      it is the Artefak 1 leak mode.
//    • Every id lookup is guarded by `flexKitRequire`; a missing id is a
//      rejected op, not a trap.
//    • `insert` / `move` position a view by its PARTICIPATING-subview index, so
//      non-managed siblings (a host-added overlay, a future scroll indicator)
//      don't shift managed views.
//
//  The caller (`FlexRenderTree.update(to:)`) guarantees the root id is unchanged
//  and that no node changed its content *kind* — both route to a full rebuild in
//  `FlexHostView.update(to:)` — so this type never has to swap a view's class.
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

@MainActor
struct FlexOpApplier {

    private let renderTree: FlexRenderTree
    private var host: FlexHostView { renderTree.owningHost }
    private var observer: FlexRenderObserver? { renderTree.owningHost.renderObserver }

    /// Ids torn down as part of an ancestor op earlier in the same batch. A
    /// later op targeting one of them is a no-op, not a rejection.
    private var settled: Set<String> = []

    init(renderTree: FlexRenderTree) {
        self.renderTree = renderTree
    }

    // MARK: - Batch

    mutating func apply(_ ops: [LayoutOp], newTree: LayoutTree) {
        let newByID = FlexOpApplier.index(of: newTree)
        // `renderTree.tree` is still the pre-update tree while ops apply — index
        // it so `updateContent` can compare old vs new props.
        let oldByID = FlexOpApplier.index(of: renderTree.tree)

        for op in ops {
            if settled.contains(op.id) { continue }

            switch op {
            case .remove(let id):
                remove(id: id)

            case .insert(let id, let parentID, let index, let subtree):
                insert(id: id, parentID: parentID, index: index, subtree: subtree)

            case .move(let id, let parentID, let index):
                move(id: id, toParent: parentID, index: index)

            case .updateStyle(let id, let delta):
                updateStyle(id: id, delta: delta, newSubtree: newByID[id])

            case .updateContent(let id):
                updateContent(id: id, oldSubtree: oldByID[id], newSubtree: newByID[id])

            case .replaceRoot:
                // `Reconciler` only emits this when the root id changed, which
                // `FlexHostView.update(to:)` intercepts and turns into a full
                // rebuild. Reaching it here means the routing contract broke.
                flexKitRequire(
                    false,
                    operation: "FlexOpApplier.replaceRoot",
                    "replaceRoot reached the incremental applier; root identity change "
                        + "must be handled by a full rebuild",
                    observer: observer
                )
            }
        }
    }

    // MARK: - Ops

    private mutating func remove(id: String) {
        guard let item = renderTree.item(id: id) else { return }  // already gone via an ancestor
        item.node.removeFromParent()
        item.view?.removeFromSuperview()
        settled.formUnion(renderTree.unregisterSubtree(id: id))
    }

    private mutating func insert(id: String, parentID: String, index: Int, subtree: LayoutTree) {
        guard
            let parent = renderTree.item(id: parentID),
            let parentView = parent.view
        else {
            flexKitRequire(
                false, operation: "FlexOpApplier.insert",
                "no live parent '\(parentID)' for inserted node '\(id)'",
                observer: observer
            )
            return
        }
        guard !parent.content.isLeaf else {
            flexKitRequire(
                false, operation: "FlexOpApplier.insert",
                "cannot insert '\(id)' under leaf node '\(parentID)'",
                observer: observer
            )
            return
        }

        let built = renderTree.buildSubtree(subtree)
        let nodeIndex = max(0, min(index, parent.node.childCount))
        parent.node.insertChild(built.node, at: nodeIndex)
        parentView.insertSubview(
            built.view, at: participatingSubviewIndex(in: parentView, forChild: nodeIndex)
        )
    }

    private mutating func move(id: String, toParent parentID: String, index: Int) {
        guard
            let item = renderTree.item(id: id),
            let view = item.view,
            let newParent = renderTree.item(id: parentID),
            let newParentView = newParent.view
        else {
            flexKitRequire(
                false, operation: "FlexOpApplier.move",
                "no live node/parent for move of '\(id)' to '\(parentID)'",
                observer: observer
            )
            return
        }

        // Detach from wherever the node currently sits, then re-attach under the
        // destination parent. `Reconciler` only ever emits same-parent reorders
        // today; a cross-parent move (remove + insert of an existing node) works
        // through the identical path.
        let node = item.node
        node.removeFromParent()
        view.removeFromSuperview()

        let nodeIndex = max(0, min(index, newParent.node.childCount))
        newParent.node.insertChild(node, at: nodeIndex)
        newParentView.insertSubview(
            view, at: participatingSubviewIndex(in: newParentView, forChild: nodeIndex)
        )
    }

    private mutating func updateStyle(id: String, delta: FlexStyleDelta, newSubtree: LayoutTree?) {
        guard let item = renderTree.item(id: id), let view = item.view else {
            flexKitRequire(
                false, operation: "FlexOpApplier.updateStyle",
                "no live node for style update of '\(id)'",
                observer: observer
            )
            return
        }
        item.node.applyDelta(delta)

        // `overflow` / `display` are the only style fields a built-in factory
        // also reflects on the view itself (`clipsToBounds`). Refresh the view
        // when one of them moved.
        let touchesViewProps =
            delta.changed.overflow != nil || delta.cleared.contains(.overflow)
            || delta.changed.display != nil || delta.cleared.contains(.display)
        if touchesViewProps, let newSubtree {
            FlexRenderTree
                .resolveFactory(for: item.content, in: renderTree.registry, host: host)
                .update(view, for: newSubtree)
        }
    }

    private mutating func updateContent(
        id: String,
        oldSubtree: LayoutTree?,
        newSubtree: LayoutTree?
    ) {
        guard let item = renderTree.item(id: id), let view = item.view else {
            flexKitRequire(
                false, operation: "FlexOpApplier.updateContent",
                "no live node for content update of '\(id)'",
                observer: observer
            )
            return
        }
        guard let newSubtree else {
            flexKitRequire(
                false, operation: "FlexOpApplier.updateContent",
                "no new subtree for content update of '\(id)'",
                observer: observer
            )
            return
        }

        FlexRenderTree
            .resolveFactory(for: item.content, in: renderTree.registry, host: host)
            .update(view, for: newSubtree)

        // Re-measure only when a size-affecting `props` key actually moved — a
        // colour-only change refreshes the view above but must not dirty layout.
        if item.isMeasuredLeaf,
           ContentInvalidation.requiresRemeasure(
               content: item.content, old: oldSubtree?.props, new: newSubtree.props
           ) {
            item.node.markContentDirty()
        }
    }

    // MARK: - Helpers

    /// The `subviews` index at which the `childOrdinal`-th managed child should
    /// sit, skipping any non-participating views.
    private func participatingSubviewIndex(in parent: UIView, forChild childOrdinal: Int) -> Int {
        var managedSeen = 0
        for (subviewIndex, sub) in parent.subviews.enumerated() {
            if managedSeen == childOrdinal { return subviewIndex }
            if sub.flexNode != nil && sub.isIncludedInLayout { managedSeen += 1 }
        }
        return parent.subviews.count
    }

    /// `id → LayoutTree` for every node in `tree`, so `updateStyle` /
    /// `updateContent` can recover the node they name.
    static func index(of tree: LayoutTree) -> [String: LayoutTree] {
        var out: [String: LayoutTree] = [:]
        func walk(_ node: LayoutTree) {
            out[node.id] = node
            node.children.forEach(walk)
        }
        walk(tree)
        return out
    }
}
#endif
