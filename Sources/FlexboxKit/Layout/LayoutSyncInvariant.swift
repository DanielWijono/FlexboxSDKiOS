//
//  LayoutSyncInvariant.swift
//  FlexboxKit
//
//  The DEBUG tree-sync gate (spec Artefak 3 §Inti "Sinkronisasi pohon",
//  ARCHITECTURE.md §"Leak gates"): at every managed container, the Yoga child
//  list and the list of subviews carrying a node must agree in COUNT and ORDER.
//
//  Why it earns its own pass rather than being folded into `FlexOpApplier`: the
//  applier can only check what it just wrote, while the two trees also drift
//  from the outside — an `addSubview` / `removeFromSuperview` the app performs
//  on a managed container, which the renderer never hears about. A drift is not
//  cosmetic: a stray subview gets no node and is therefore never positioned
//  (it sits at whatever frame it was created with), and a managed view whose
//  node was left behind is the Artefak 1 leak mode.
//
//  Three things are checked at each container:
//    1. count      — `node.childCount` == subviews that carry a node
//    2. no strays  — every node-less subview that takes part in layout
//    3. order      — the n-th node-carrying subview holds `node.children[n]`
//
//  What is deliberately NOT checked:
//    • a leaf's view internals. A `text` / `image` / `custom` node's view is
//      the factory's own composition (a `UILabel`, or a consumer's composed
//      control); the renderer owns no children under it.
//    • unmanaged subviews of a `UIScrollView`. UIKit adds its own scroll
//      indicators to `subviews` and they cannot be marked
//      `isIncludedInLayout = false`, so a stray there is expected.
//
//  A view the app positions itself is declared with
//  `isIncludedInLayout = false` (see `LayoutParticipation`) — that is the
//  documented escape hatch, and the reason check 2 can be strict. Note the flag
//  means two different things depending on where it is set: on a view the app
//  added it means "no node exists for this" (checks 1 and 3 never see it); on a
//  view the renderer BUILT from the payload it only suppresses geometry, and
//  the node keeps its place in the flow — so such a view still counts in checks
//  1 and 3.
//
//  DEBUG only, and compiled out entirely otherwise: the walk is O(nodes) per
//  geometry pass. Reported through `flexKitRequire`, so a violation traps in
//  development and — when a test clears `FlexKitPrecondition.assertsAreFatal` —
//  reports to the observer and returns without mutating anything.
//

#if canImport(UIKit) && DEBUG
import UIKit
import FlexboxCore

@MainActor
enum LayoutSyncInvariant {

    /// The `operation:` label every violation is reported under.
    static let operation: StaticString = "FlexHostView.treeSync"

    /// Walks `renderTree` from its root view, reporting each disagreement
    /// between the node tree and the view tree.
    static func check(_ renderTree: FlexRenderTree, observer: FlexRenderObserver?) {
        // One identity map up front: the alternative, `idForNode` per child, is
        // a linear scan inside a walk — quadratic on a deep tree.
        var idByNode: [ObjectIdentifier: String] = [:]
        for item in renderTree.allItems {
            idByNode[ObjectIdentifier(item.node)] = item.id
        }
        check(
            id: renderTree.tree.id, in: renderTree, idByNode: idByNode, observer: observer
        )
    }

    private static func check(
        id: String,
        in renderTree: FlexRenderTree,
        idByNode: [ObjectIdentifier: String],
        observer: FlexRenderObserver?
    ) {
        guard let item = renderTree.item(id: id), let view = item.view else { return }
        // A leaf owns no managed children — its view's internals belong to the
        // factory that built it.
        guard !item.content.isLeaf else { return }

        let node = item.node
        // Carrying a node is what makes a subview the renderer's, NOT
        // `isIncludedInLayout`: opting a payload-built view out only stops
        // geometry being written to it, its node keeps its place in the flow
        // (see `LayoutParticipation`). So the count and order checks read every
        // node-carrying subview, and `isIncludedInLayout` governs only which
        // node-less subviews are a stray rather than the app's own business.
        let managed = view.subviews.filter { $0.flexNode != nil }
        let strays = view.subviews.filter { $0.flexNode == nil && $0.isIncludedInLayout }

        // 1. Count. Everything below reads `node.children` by ordinal, so stop
        //    here when the two lists are not the same length.
        guard flexKitRequire(
            managed.count == node.childCount,
            operation: operation,
            "node '\(id)' has \(node.childCount) Yoga child(ren) but "
                + "\(managed.count) managed subview(s)",
            observer: observer
        ) else { return }

        // 2. Strays: a subview that takes part in layout but carries no node
        //    was added outside the `LayoutTree` and will never be positioned.
        if !(view is UIScrollView) {
            flexKitRequire(
                strays.isEmpty,
                operation: operation,
                "node '\(id)' has \(strays.count) subview(s) that take part in layout but "
                    + "carry no node — added outside the LayoutTree. Set "
                    + "`isIncludedInLayout = false` on views you position yourself",
                observer: observer
            )
        }

        // 3. Order, then recurse.
        for (ordinal, subview) in managed.enumerated() {
            guard let childNode = subview.flexNode else { continue }
            guard flexKitRequire(
                childNode === node.children[ordinal],
                operation: operation,
                "managed subview \(ordinal) of node '\(id)' carries a node that is not that "
                    + "node's child \(ordinal) — view order and Yoga child order disagree",
                observer: observer
            ) else { continue }
            guard let childID = idByNode[ObjectIdentifier(childNode)] else {
                flexKitRequire(
                    false,
                    operation: operation,
                    "child \(ordinal) of node '\(id)' is not in the render index — its view "
                        + "and node survived a teardown that should have dropped both",
                    observer: observer
                )
                continue
            }
            check(id: childID, in: renderTree, idByNode: idByNode, observer: observer)
        }
    }
}
#endif
