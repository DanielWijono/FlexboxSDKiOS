//
//  FlexNode+Children.swift
//  FlexboxCore
//
//  Structural mutation. Every Yoga fatal-assert path reachable from here is
//  fronted by `flexRequire` (spec Pillar §"Tidak boleh ada assert fatal di
//  build release"); see `YogaAssertCatalog` for the full list.
//

extension FlexNode {

    /// Inserts `child` at `index` (clamped to `0...childCount`).
    ///
    /// Rejected — without mutating state — if `child` is `self`, already has a
    /// parent, is still owned by another Yoga node, or if either node carries a
    /// measure function (a measured node must stay a leaf).
    public func insertChild(_ child: FlexNode, at index: Int) {
        guard flexRequire(
            child !== self,
            operation: "FlexNode.insertChild",
            "a node cannot be its own child"
        ) else { return }

        guard flexRequire(
            child.parent == nil,
            operation: "FlexNode.insertChild",
            "child already has a parent; remove it from its current parent first"
        ) else { return }

        guard flexRequire(
            yoga_owner(of: child.handle) == nil,
            operation: "FlexNode.insertChild",
            "child is still owned by another Yoga node"
        ) else { return }

        guard flexRequire(
            measureFunction == nil && !yoga_hasMeasureFunc(handle),
            operation: "FlexNode.insertChild",
            "cannot add children to a node that has a measure function"
        ) else { return }

        guard flexRequire(
            child.measureFunction == nil || child.children.isEmpty,
            operation: "FlexNode.insertChild",
            "measured child must be a leaf"
        ) else { return }

        let clamped = max(0, min(index, children.count))
        children.insert(child, at: clamped)
        child.parent = self
        yoga_insertChild(child.handle, into: handle, at: clamped)
        assertChildInvariant()
    }

    /// Appends `child` as the last child.
    public func appendChild(_ child: FlexNode) {
        insertChild(child, at: children.count)
    }

    /// Removes `child`. `YGNodeRemoveChild` is called before the Swift list is
    /// updated (spec §"Aturan pembongkaran": reparenting must remove first).
    /// Rejected if `child` is not actually a child of this node.
    public func removeChild(_ child: FlexNode) {
        guard let idx = children.firstIndex(where: { $0 === child }) else {
            flexRequire(
                false,
                operation: "FlexNode.removeChild",
                "node is not a child of this node"
            )
            return
        }
        yoga_removeChild(child.handle, from: handle)
        children.remove(at: idx)
        child.parent = nil
        assertChildInvariant()
    }

    /// Detaches this node from its parent, if any.
    public func removeFromParent() {
        parent?.removeChild(self)
    }

    /// Moves `child` (already a child of this node) to `index`. Implemented as
    /// remove-then-insert so Yoga's owner linkage is always consistent.
    public func moveChild(_ child: FlexNode, to index: Int) {
        guard children.contains(where: { $0 === child }) else {
            flexRequire(
                false,
                operation: "FlexNode.moveChild",
                "node is not a child of this node"
            )
            return
        }
        removeChild(child)
        insertChild(child, at: index)
    }
}
