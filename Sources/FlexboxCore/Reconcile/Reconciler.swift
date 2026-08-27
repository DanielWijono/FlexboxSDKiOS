//
//  Reconciler.swift
//  FlexboxCore
//
//  The diff engine — the most direct demonstration of "layout is data" (spec
//  Artefak 2 §"Rekonsiliasi"). A PURE function of two values: no Yoga, no
//  views, no traps. Children are matched by `id`, not by position, so a
//  reorder becomes `move` rather than remove + insert.
//
//  A node that changes parent is expressed as remove-under-old-parent +
//  insert-under-new-parent. Correct, though not the theoretical minimum; noted
//  in ARCHITECTURE.md.
//

public enum Reconciler {

    /// Operations that transform `old` into `new`. Order is applyable as-is:
    /// removals first per level, then insertions in destination order, then
    /// moves, then per-node style/content updates, then recursion.
    public static func reconcile(from old: LayoutTree, to new: LayoutTree) -> [LayoutOp] {
        var ops: [LayoutOp] = []
        if old.id != new.id {
            ops = [.replaceRoot(subtree: new)]
        } else {
            diffNode(old: old, new: new, into: &ops)
        }
        FlexTelemetry.reconciled(operationCount: ops.count)
        return ops
    }

    private static func diffNode(old: LayoutTree, new: LayoutTree, into ops: inout [LayoutOp]) {
        if old.content != new.content || old.props != new.props {
            ops.append(.updateContent(id: new.id))
        }

        let delta = new.style.delta(from: old.style)
        if !delta.isEmpty {
            ops.append(.updateStyle(id: new.id, delta: delta))
        }

        diffChildren(parentID: new.id, old: old.children, new: new.children, into: &ops)
    }

    private static func diffChildren(
        parentID: String,
        old: [LayoutTree],
        new: [LayoutTree],
        into ops: inout [LayoutOp]
    ) {
        var oldByID: [String: LayoutTree] = [:]
        for child in old { oldByID[child.id] = child }
        let oldIDs = old.map(\.id)
        let newIDs = new.map(\.id)
        let oldSet = Set(oldIDs)
        let newSet = Set(newIDs)

        // Removals: present in old, absent in new.
        for id in oldIDs where !newSet.contains(id) {
            ops.append(.remove(id: id))
        }

        // Insertions: present in new, absent in old. Destination order, so a
        // parent is always inserted before its children.
        for (index, child) in new.enumerated() where !oldSet.contains(child.id) {
            ops.append(.insert(id: child.id, parentID: parentID, index: index, subtree: child))
        }

        // Reorders among survivors.
        let survivingOld = oldIDs.filter(newSet.contains)
        let survivingNew = newIDs.filter(oldSet.contains)
        if survivingOld != survivingNew {
            for (finalIndex, child) in new.enumerated() where oldSet.contains(child.id) {
                let a = survivingOld.firstIndex(of: child.id)
                let b = survivingNew.firstIndex(of: child.id)
                if a != b {
                    ops.append(.move(id: child.id, parentID: parentID, index: finalIndex))
                }
            }
        }

        // Recurse into survivors.
        for child in new {
            guard let oldChild = oldByID[child.id] else { continue }
            diffNode(old: oldChild, new: child, into: &ops)
        }
    }
}
