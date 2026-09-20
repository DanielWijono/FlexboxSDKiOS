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
    /// Not `private`: `FlexHostView+SelfSizing` enters/leaves it too.
    let reentrancy = MeasureReentrancyGuard()
    private var renderTree: FlexRenderTree!

    /// Yoga errata level for this tree. Fixed at construction — make a new host
    /// to change it.
    public let errata: FlexErrata

    /// Per-host diagnostics sink. See `FlexRenderObserver`.
    public weak var renderObserver: FlexRenderObserver?

    /// Whether — and on which edges — the device safe area insets the root
    /// node's children. Default `.ignore` (explicit opt-in). See
    /// `FlexHostView+SafeArea`.
    public var safeAreaMode: FlexSafeAreaMode = .ignore {
        didSet { if safeAreaMode != oldValue { setNeedsLayout() } }
    }

    /// Whether `overflow: scroll` nodes are backed by a `UIScrollView`. Default
    /// `.automatic`. Whether a given node is backed by a scroll view is decided
    /// when its view is built, so changing this rebinds the current tree.
    public var scrollBehavior: FlexScrollBehavior = .automatic {
        didSet {
            guard scrollBehavior != oldValue, renderTree != nil else { return }
            rebuildRenderTree(with: renderTree.tree)
        }
    }

    /// Size produced by the most recent self-size pass — returned while a pass
    /// is re-entered (see `MeasureReentrancyGuard`).
    var lastSelfSizedResult: CGSize = .zero

    /// Whether the last pass wrote safe-area insets onto the root node's border.
    /// Lets `flexApplySafeAreaToRoot` leave the root untouched while the mode is
    /// `.ignore`, yet still restore the payload's own border on the one pass
    /// after the insets go away.
    var hasWrittenSafeAreaBorder = false

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

    /// Replaces the rendered tree with the minimal set of view/node mutations
    /// (`Reconciler` → `FlexOpApplier`), preserving view identity, scroll
    /// position and any in-flight animation on the views that survive.
    ///
    /// Two changes can't be expressed as an in-place diff and fall back to a
    /// full rebuild: the root `id` changed, or some node changed its content
    /// *kind* (e.g. `text` → `image`), which needs a different `UIView` class.
    public func update(to newTree: LayoutTree) {
        let current = renderTree.tree
        if newTree.id != current.id || FlexHostView.contentKindDiffers(current, newTree) {
            rebuildRenderTree(with: newTree)
        } else {
            renderTree.update(to: newTree)
            setNeedsLayout()
        }
        // A new tree usually means a new self-sized extent — let a surrounding
        // Auto Layout pass re-query `intrinsicContentSize`.
        invalidateIntrinsicContentSize()
    }

    /// `true` if any id shared by both trees carries a different `content` kind.
    static func contentKindDiffers(_ a: LayoutTree, _ b: LayoutTree) -> Bool {
        if a.content != b.content { return true }
        var kindByID: [String: ContentType] = [:]
        for node in b.flexFlattened() { kindByID[node.id] = node.content }
        for node in a.flexFlattened() {
            if let newKind = kindByID[node.id], newKind != node.content { return true }
        }
        return false
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
        // `enter()` always bumps the depth counter — pair it with `leave()`
        // unconditionally, then bail if a pass is already running.
        let outermost = reentrancy.enter()
        defer { reentrancy.leave() }
        guard outermost else { return }
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

        // Fold in view-driven state that carries no tree update: a subview's
        // `isHidden` → `display: none` (siblings reflow), and the device safe
        // area when the host opted into `.padRoot`.
        flexReconcileHiddenDisplay(in: renderTree)

        let direction = flexWritingDirection(for: self)
        flexApplySafeAreaToRoot(direction: direction)

        #if DEBUG
        // Tree-sync gate, before the result is trusted: the node tree and the
        // view tree must still agree in count and order. Only on a
        // geometry-applying pass — a measure-only pass sees the same trees and
        // would just double-report.
        if applyGeometry {
            LayoutSyncInvariant.check(renderTree, observer: renderObserver)
        }
        #endif

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

        // A measure-only pass (the self-size hooks) has laid nothing out — only a
        // geometry-applying pass counts as a host layout for the observer.
        if applyGeometry {
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            let nodeCount = renderTree.root.nodeCount
            renderObserver?.flexHostDidLayout(nodeCount: nodeCount, durationNanos: elapsed)
            FlexboxCoreBridge.reportCalculated(nodeCount: nodeCount, durationNanos: elapsed)
        }
        return measured
    }

    private func applyGeometryToManagedSubviews(of view: UIView) {
        for sub in view.subviews where sub.isIncludedInLayout {
            guard let node = sub.flexNode else { continue }
            GeometryApplier.apply(node.layout, to: sub)
            applyGeometryToManagedSubviews(of: sub)
            if let scroll = sub as? FlexScrollBackingView {
                // Post-pass: the scroll view's own box is `node`'s flex size
                // (applied above); its scrollable content is the extent of its
                // children. `contentOffset` is untouched — GeometryApplier
                // preserved `bounds.origin`.
                scroll.contentSize = ScrollContentSizing.contentSize(for: node)
            }
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
        // The fresh root carries the payload's own border; the next pass decides
        // again whether to stack the safe area on top of it.
        hasWrittenSafeAreaBorder = false
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
