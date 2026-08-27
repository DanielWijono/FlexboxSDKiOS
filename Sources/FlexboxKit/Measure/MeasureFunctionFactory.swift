//
//  MeasureFunctionFactory.swift
//  FlexboxKit
//
//  Builds the `FlexMeasureFunction` for a leaf: a closure Yoga calls during
//  `calculate` to learn the leaf's natural size under per-axis constraints.
//
//  Contract (spec Artefak 1 §Konkurensi, ARCHITECTURE.md): the closure consults
//  UIKit (`sizeThatFits`) and therefore MUST run on the main thread. Core types
//  `FlexMeasureFunction` as `@Sendable`, so the view and factory are reached
//  through a `@unchecked Sendable` context that asserts the thread and refuses
//  to touch UIKit off-main.
//
//  The closure captures the context only — never the `FlexNode`, never the view
//  strongly (spec: no retain cycle).
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

/// Per-leaf measurement context. `@unchecked Sendable`: it holds a `weak` view
/// and is only ever exercised on the main thread (asserted).
final class MeasureContext: @unchecked Sendable {

    let id: String
    weak var view: UIView?
    let factory: any FlexViewFactory
    let cache: MeasureCache

    @MainActor
    init(id: String, view: UIView, factory: any FlexViewFactory, cache: MeasureCache) {
        self.id = id
        self.view = view
        self.factory = factory
        self.cache = cache
    }

    func measure(
        _ width: FlexMeasureConstraint,
        _ height: FlexMeasureConstraint
    ) -> FlexSize {
        let key = MeasureCache.Key(id: id, width: width, height: height)
        if let hit = cache.lookup(key) { return hit }

        guard flexKitRequire(
            Thread.isMainThread,
            operation: "FlexboxKit.measure",
            "measure function for '\(id)' ran off the main thread"
        ) else {
            return .zero
        }

        // The thread check above establishes we are on the main thread; Core
        // just cannot express that in the `@Sendable` closure type.
        let size = MainActor.assumeIsolated { () -> FlexSize in
            guard let view else { return .zero }
            return factory.measure(view, width: width, height: height) ?? .zero
        }
        cache.store(size, for: key)
        return size
    }
}

enum MeasureFunctionFactory {

    /// A `FlexMeasureFunction` bound to `view` via `factory`, memoized in `cache`.
    @MainActor
    static func make(
        id: String,
        view: UIView,
        factory: any FlexViewFactory,
        cache: MeasureCache
    ) -> FlexMeasureFunction {
        let context = MeasureContext(id: id, view: view, factory: factory, cache: cache)
        return { width, height in context.measure(width, height) }
    }
}
#endif
