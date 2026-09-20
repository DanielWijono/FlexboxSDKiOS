//
//  HostHarness.swift
//  FlexboxKitTestSupport
//
//  Stands a `FlexHostView` in a real `UIWindow` and forces a synchronous layout
//  pass, so tests can read final `frame`s. Also the tree-walk helpers the leak
//  and invariant gates use.
//

#if canImport(UIKit)
import UIKit
import FlexboxKit
import FlexboxCore

@MainActor
public enum HostHarness {

    /// A window-hosted `FlexHostView` sized to `size`, laid out once.
    public static func mount(
        _ tree: LayoutTree,
        registry: FlexViewRegistry = .default,
        size: CGSize = CGSize(width: 320, height: 568)
    ) -> (window: UIWindow, host: FlexHostView) {
        let host = FlexHostView(tree: tree, registry: registry)
        return finishMount(host: host, size: size)
    }

    /// As `mount`, but for a host the caller built (e.g. from a `LayoutResolution`).
    public static func finishMount(
        host: FlexHostView,
        size: CGSize = CGSize(width: 320, height: 568)
    ) -> (window: UIWindow, host: FlexHostView) {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        host.frame = window.bounds
        window.addSubview(host)
        window.makeKeyAndVisible()
        host.setNeedsLayout()
        host.layoutIfNeeded()
        return (window, host)
    }

    /// A window-hosted `FlexHostView` whose safe area the test controls.
    ///
    /// The insets come from a real `UIViewController.additionalSafeAreaInsets`
    /// rather than a stub, so the host sees the same propagation path it sees in
    /// an app. The device's own insets are added to these by UIKit, so assert
    /// against `host.safeAreaInsets` rather than against the value passed here.
    public static func mountInViewController(
        _ tree: LayoutTree,
        additionalSafeAreaInsets: UIEdgeInsets,
        registry: FlexViewRegistry = .default,
        size: CGSize = CGSize(width: 320, height: 568)
    ) -> (window: UIWindow, controller: UIViewController, host: FlexHostView) {
        let host = FlexHostView(tree: tree, registry: registry)
        let controller = UIViewController()
        controller.additionalSafeAreaInsets = additionalSafeAreaInsets

        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()

        host.frame = controller.view.bounds
        host.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.view.addSubview(host)

        window.layoutIfNeeded()
        host.setNeedsLayout()
        host.layoutIfNeeded()
        return (window, controller, host)
    }

    /// Forces another synchronous layout pass.
    public static func relayout(_ host: FlexHostView) {
        host.setNeedsLayout()
        host.layoutIfNeeded()
    }

    // MARK: Tree walking

    /// All managed subviews (those with a `flexNode` and `isIncludedInLayout`)
    /// under `view`, pre-order.
    public static func managedSubviews(under view: UIView) -> [UIView] {
        var out: [UIView] = []
        for sub in view.subviews where sub.isIncludedInLayout && sub.flexNode != nil {
            out.append(sub)
            out.append(contentsOf: managedSubviews(under: sub))
        }
        return out
    }

    /// `true` iff, at every managed node, the Yoga child count equals the
    /// participating-subview count (spec §"Gerbang kebocoran" DEBUG invariant,
    /// checked here from the view side too).
    public static func childCountInvariantHolds(from view: UIView) -> Bool {
        for sub in view.subviews where sub.isIncludedInLayout && sub.flexNode != nil {
            guard let node = sub.flexNode else { return false }
            let participating = sub.subviews.filter { $0.isIncludedInLayout && $0.flexNode != nil }.count
            if participating != node.childCount { return false }
            if !childCountInvariantHolds(from: sub) { return false }
        }
        return true
    }
}
#endif
