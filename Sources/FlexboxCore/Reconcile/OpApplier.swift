//
//  OpApplier.swift
//  FlexboxCore
//
//  Binds a `LayoutTree` value to a live `FlexNode` tree and keeps them in sync
//  by applying `[LayoutOp]` from the `Reconciler`. This is the seam between the
//  value layer (Artefak 2) and the engine (Artefak 1).
//
//  The op → VIEW side (a registry of content-type → view factory) is Artefak 3.
//  Here, leaves are structural only; `updateContent` merely validates the id.
//
//  Every id lookup that could reference a missing node is guarded — a bad op
//  sequence is a rejected no-op, never a trap (spec Pillar).
//

public final class FlexLayoutBinding {

    public let config: FlexConfig

    /// The value the live tree currently reflects.
    public private(set) var tree: LayoutTree

    /// The live root. Retain the binding for the duration of any `calculate`.
    public private(set) var root: FlexNode

    private var nodesByID: [String: FlexNode] = [:]
    private var idByNode: [ObjectIdentifier: String] = [:]

    public init(tree: LayoutTree, config: FlexConfig = .default) {
        self.config = config
        self.tree = tree
        self.root = FlexNode(config: config)
        build(tree, into: root)
        register(root, id: tree.id)
    }

    /// The live node for `id`, if present.
    public func node(id: String) -> FlexNode? { nodesByID[id] }

    /// Reconciles the live tree to `newTree` and applies the minimal ops.
    @discardableResult
    public func update(to newTree: LayoutTree) -> [LayoutOp] {
        let ops = Reconciler.reconcile(from: tree, to: newTree)
        apply(ops)
        tree = newTree
        return ops
    }

    /// Applies a precomputed op list. Exposed for testing and for callers that
    /// diff elsewhere.
    public func apply(_ ops: [LayoutOp]) {
        for op in ops { apply(op) }
    }

    // MARK: - Op application

    private func apply(_ op: LayoutOp) {
        switch op {
        case .replaceRoot(let subtree):
            nodesByID.removeAll()
            idByNode.removeAll()
            let newRoot = FlexNode(config: config)
            build(subtree, into: newRoot)
            register(newRoot, id: subtree.id)
            root = newRoot

        case .insert(_, let parentID, let index, let subtree):
            guard let parent = nodesByID[parentID] else {
                flexRequire(false, operation: "OpApplier.insert",
                            "parent id '\(parentID)' not found in working tree")
                return
            }
            let child = FlexNode(config: config)
            build(subtree, into: child)
            register(child, id: subtree.id)
            parent.insertChild(child, at: index)

        case .remove(let id):
            guard let node = nodesByID[id] else {
                flexRequire(false, operation: "OpApplier.remove",
                            "node id '\(id)' not found in working tree")
                return
            }
            unregisterSubtree(node)
            node.removeFromParent()

        case .move(let id, let parentID, let index):
            guard let node = nodesByID[id] else {
                flexRequire(false, operation: "OpApplier.move",
                            "node id '\(id)' not found in working tree")
                return
            }
            guard let parent = nodesByID[parentID] else {
                flexRequire(false, operation: "OpApplier.move",
                            "destination parent id '\(parentID)' not found")
                return
            }
            node.removeFromParent()
            parent.insertChild(node, at: index)

        case .updateStyle(let id, let delta):
            guard let node = nodesByID[id] else {
                flexRequire(false, operation: "OpApplier.updateStyle",
                            "node id '\(id)' not found in working tree")
                return
            }
            node.applyDelta(delta)

        case .updateContent(let id):
            guard nodesByID[id] != nil else {
                flexRequire(false, operation: "OpApplier.updateContent",
                            "node id '\(id)' not found in working tree")
                return
            }
            // Renderer refresh + markContentDirty() for leaves is Artefak 3.
        }
    }

    // MARK: - Tree construction / registry

    /// Builds `subtree`'s children onto an already-created `node` and applies
    /// `subtree.style` to it.
    private func build(_ subtree: LayoutTree, into node: FlexNode) {
        node.apply(subtree.style)
        for childTree in subtree.children {
            let child = FlexNode(config: config)
            build(childTree, into: child)
            register(child, id: childTree.id)
            node.appendChild(child)
        }
    }

    private func register(_ node: FlexNode, id: String) {
        nodesByID[id] = node
        idByNode[ObjectIdentifier(node)] = id
    }

    private func unregisterSubtree(_ node: FlexNode) {
        if let id = idByNode.removeValue(forKey: ObjectIdentifier(node)) {
            nodesByID.removeValue(forKey: id)
        }
        for child in node.children {
            unregisterSubtree(child)
        }
    }
}
