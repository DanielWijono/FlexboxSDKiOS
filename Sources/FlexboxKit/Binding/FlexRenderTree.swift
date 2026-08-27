//
//  FlexRenderTree.swift
//  FlexboxKit
//
//  FlexboxKit's answer to FlexboxCore's `FlexLayoutBinding`: it keeps a live
//  `FlexNode` tree and a parallel `UIView` tree in step, indexed by stable `id`.
//
//  Core is kept frozen (user decision): this type calls the public, pure
//  `Reconciler.reconcile(from:to:)` itself and drives both trees through
//  `FlexOpApplier`, rather than reusing `FlexLayoutBinding` (which has no per-op
//  hook, no reverse id lookup, and installs no measure functions).
//
//  Main-actor isolated — the renderer is main-thread confined.
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

@MainActor
final class FlexRenderTree {

    let config: FlexConfig
    private(set) var tree: LayoutTree
    private(set) var root: FlexNode
    private(set) var rootView: UIView

    private(set) var registry: FlexViewRegistry
    private unowned let host: FlexHostView
    let cache: MeasureCache

    /// `id → (node, view)`. Strong on `node`, weak on `view` (see `RenderItem`).
    private(set) var itemsByID: [String: RenderItem] = [:]

    init(
        tree: LayoutTree,
        config: FlexConfig,
        registry: FlexViewRegistry,
        host: FlexHostView,
        cache: MeasureCache
    ) {
        self.config = config
        self.tree = tree
        self.registry = registry
        self.host = host
        self.cache = cache

        let built = FlexRenderTree.buildDetached(
            subtree: tree, config: config, registry: registry, host: host, cache: cache,
            into: &itemsByID
        )
        self.root = built.node
        self.rootView = built.view
    }

    // MARK: - Lookup

    func node(id: String) -> FlexNode? { itemsByID[id]?.node }
    func view(id: String) -> UIView? { itemsByID[id]?.view }
    func item(id: String) -> RenderItem? { itemsByID[id] }

    // MARK: - Registry / index maintenance (used by FlexOpApplier)

    func setRegistry(_ registry: FlexViewRegistry) { self.registry = registry }

    func setRoot(node: FlexNode, view: UIView) {
        self.root = node
        self.rootView = view
    }

    func setTree(_ tree: LayoutTree) { self.tree = tree }

    func registerItem(_ item: RenderItem) { itemsByID[item.id] = item }

    /// Removes a node and its whole subtree from the index, breaking each
    /// node↔view association. Does not touch the Yoga parent linkage or the view
    /// hierarchy — the caller does that.
    func unregisterSubtree(id: String) {
        guard let item = itemsByID[id] else { return }
        NodeViewAssociation.unlink(view: item.view, node: item.node)
        for child in item.node.children {
            if let childID = idForNode(child) {
                unregisterSubtree(id: childID)
            }
        }
        itemsByID.removeValue(forKey: id)
    }

    /// Reverse lookup `FlexNode → id` by identity. Linear; used only during
    /// subtree teardown where the set is small.
    func idForNode(_ node: FlexNode) -> String? {
        for (id, item) in itemsByID where item.node === node { return id }
        return nil
    }

    // MARK: - Construction

    /// Builds a detached `FlexNode` + `UIView` subtree for `subtree`, wiring
    /// styles, node↔view associations and leaf measure functions, and registers
    /// every node in `index`. The result is not attached to any parent.
    static func buildDetached(
        subtree: LayoutTree,
        config: FlexConfig,
        registry: FlexViewRegistry,
        host: FlexHostView,
        cache: MeasureCache,
        into index: inout [String: RenderItem]
    ) -> (node: FlexNode, view: UIView) {

        let node = FlexNode(config: config)
        node.apply(subtree.style)

        let resolved = resolveFactory(for: subtree.content, in: registry, host: host)
        let view = resolved.makeView(for: subtree)
        view.translatesAutoresizingMaskIntoConstraints = true
        NodeViewAssociation.link(view: view, node: node, host: host)

        var isMeasuredLeaf = false
        if subtree.content.isLeaf {
            flexKitRequire(
                subtree.children.isEmpty,
                operation: "FlexRenderTree.build",
                "leaf node '\(subtree.id)' has children; ignoring them",
                observer: host.renderObserver
            )
            let measure = MeasureFunctionFactory.make(
                id: subtree.id, view: view, factory: resolved, cache: cache
            )
            node.setMeasure(measure)
            isMeasuredLeaf = true
        } else {
            for childTree in subtree.children {
                let child = buildDetached(
                    subtree: childTree, config: config, registry: registry,
                    host: host, cache: cache, into: &index
                )
                node.appendChild(child.node)
                view.addSubview(child.view)
            }
        }

        index[subtree.id] = RenderItem(
            id: subtree.id, node: node, view: view,
            content: subtree.content, isMeasuredLeaf: isMeasuredLeaf
        )
        return (node, view)
    }

    /// The factory for `content`, or a plain container factory if the content
    /// type is unregistered (a rejected op, not a trap).
    static func resolveFactory(
        for content: ContentType,
        in registry: FlexViewRegistry,
        host: FlexHostView
    ) -> any FlexViewFactory {
        if let factory = registry.factory(for: content) { return factory }
        flexKitRequire(
            false,
            operation: "FlexViewRegistry.resolve",
            "no factory registered for content '\(content.registryKey)'; using a plain container",
            observer: host.renderObserver
        )
        return ContainerViewFactory()
    }
}
#endif
