//
//  FlexHostView.swift
//  FlexboxKit
//
//  The renderer's entry point: a `UIView` that owns a `LayoutTree`, runs a Yoga
//  pass from `layoutSubviews`, and applies the result to its managed subviews'
//  `bounds.size` / `center`.
//
//  Layout is triggered ONLY from `layoutSubviews` (spec Artefak 3 §Inti): no
//  `UIView` extension override, no method swizzling. The app drives it the
//  normal way — `setNeedsLayout()`, a resize, a constraint change.
//
//  EXPERIMENTAL API (until Artefak 4).
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

public final class FlexHostView: UIView {

    // MARK: Stored state

    private var config: FlexConfig
    private var registry: FlexViewRegistry
    private let cache = MeasureCache()
    private let reentrancy = MeasureReentrancyGuard()
    private var renderTree: FlexRenderTree!

    /// Yoga errata level for this tree. Fixed at construction — make a new host
    /// to change it.
    public let errata: FlexErrata

    /// Per-host diagnostics sink. See `FlexRenderObserver`.
    public weak var renderObserver: FlexRenderObserver?

    /// How the device safe area is folded into the root node's padding. Default
    /// `.ignore` (explicit opt-in).
    public var safeAreaMode: FlexSafeAreaMode = .ignore {
        didSet { if safeAreaMode != oldValue { setNeedsLayout() } }
    }

    /// Whether `overflow: scroll` nodes are backed by a `UIScrollView`. Default
    /// `.automatic`.
    public var scrollBehavior: FlexScrollBehavior = .automatic

    /// Size produced by the most recent self-size pass — returned while a pass
    /// is re-entered (see `MeasureReentrancyGuard`).
    var lastSelfSizedResult: CGSize = .zero

    // MARK: Init

    /// Renders `tree`. `registry` maps content types to views; `errata` sets the
    /// Yoga compatibility level.
    public init(
        tree: LayoutTree,
        registry: FlexViewRegistry = .default,
        errata: FlexErrata = .none
    ) {
        self.registry = registry
        self.errata = errata
        self.config = FlexConfigFactory.makeConfig(
            displayScale: UITraitCollection.current.displayScale, errata: errata
        )
        super.init(frame: .zero)
        rebuildRenderTree(with: tree)
    }

    /// Renders `resolution.tree`; reports a fallback selection to the observer.
    public convenience init(
        resolution: LayoutResolution,
        registry: FlexViewRegistry = .default,
        errata: FlexErrata = .none
    ) {
        self.init(tree: resolution.tree, registry: registry, errata: errata)
        if case .fallback(_, let reason) = resolution {
            renderObserver?.flexHostDidUseFallback(reason: reason.description)
            FlexboxCoreBridge.reportUsedFallback(reason: reason.description)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        // Programmatic only: a host needs a LayoutTree, which a coder cannot
        // supply. This is construction misuse, surfaced immediately.
        fatalError("FlexHostView must be created with init(tree:) — NSCoder is not supported")
    }

    // MARK: Public surface

    /// The tree currently rendered.
    public var tree: LayoutTree { renderTree.tree }

    /// Replaces the rendered tree. Step 1: a full rebuild. Reconcile-driven
    /// minimal updates land in the tree-sync step.
    public func update(to newTree: LayoutTree) {
        rebuildRenderTree(with: newTree)
    }

    /// Registers a custom / override factory and rebuilds so it takes effect.
    public func register(_ factory: FlexViewFactory, for content: ContentType) {
        registry.register(factory, for: content)
        renderTree.setRegistry(registry)
        rebuildRenderTree(with: renderTree.tree)
    }

    // MARK: Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard reentrancy.enter() else { return }
        defer { reentrancy.leave() }
        runPass(availableWidth: bounds.width, availableHeight: bounds.height, applyGeometry: true)
    }

    /// Schedules a relayout unless one is already running (the running pass will
    /// pick up whatever changed).
    func flexScheduleRelayout() {
        guard !reentrancy.isActive else { return }
        setNeedsLayout()
    }

    /// Runs one Yoga pass. When `applyGeometry` is true the result is written to
    /// the managed subviews; otherwise the pass only measures (self-size path).
    /// Returns the root node's laid-out size.
    @discardableResult
    func runPass(
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        applyGeometry: Bool
    ) -> CGSize {
        let start = DispatchTime.now().uptimeNanoseconds
        cache.beginPass()

        let direction = flexWritingDirection(for: self)
        renderTree.root.calculate(
            availableWidth: Double(availableWidth),
            availableHeight: Double(availableHeight),
            direction: direction
        )

        if applyGeometry {
            renderTree.rootView.frame = bounds
            applyGeometryToManagedSubviews(of: renderTree.rootView)
        }

        let rootLayout = renderTree.root.layout
        let measured = CGSize(width: rootLayout.width, height: rootLayout.height)

        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        let nodeCount = renderTree.root.nodeCount
        renderObserver?.flexHostDidLayout(nodeCount: nodeCount, durationNanos: elapsed)
        FlexboxCoreBridge.reportCalculated(nodeCount: nodeCount, durationNanos: elapsed)
        return measured
    }

    private func applyGeometryToManagedSubviews(of view: UIView) {
        for sub in view.subviews where sub.isIncludedInLayout {
            guard let node = sub.flexNode else { continue }
            GeometryApplier.apply(node.layout, to: sub)
            applyGeometryToManagedSubviews(of: sub)
        }
    }

    // MARK: Build / teardown

    func currentConfig() -> FlexConfig { config }
    func currentCache() -> MeasureCache { cache }

    private func rebuildRenderTree(with tree: LayoutTree) {
        if let existing = renderTree {
            existing.unregisterSubtree(id: existing.tree.id)
            existing.rootView.removeFromSuperview()
        }
        renderTree = FlexRenderTree(
            tree: tree, config: config, registry: registry, host: self, cache: cache
        )
        addSubview(renderTree.rootView)
        setNeedsLayout()
    }

    /// Swaps in a fresh config (e.g. after a display-scale change) and rebinds
    /// the current tree to it. `FlexConfig` is per-tree and immutable in Core.
    func rebindToConfig(_ newConfig: FlexConfig) {
        config = newConfig
        rebuildRenderTree(with: renderTree.tree)
    }

    /// The live render tree. For test support / extensions in this module.
    var currentRenderTree: FlexRenderTree { renderTree }
}
#endif
