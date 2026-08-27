//
//  NodeViewAssociation.swift
//  FlexboxKit
//
//  The `UIView` ↔ `FlexNode` link.
//
//    UIView  → FlexNode : STRONG, via an associated object. A view keeps its
//                         node alive for as long as the view is in a hierarchy.
//    FlexNode → UIView  : WEAK (see `RenderItem.view`). Reversing this direction
//                         is the retain cycle the ownership contract removes.
//
//  `onDirtied` is wired here so an engine-level dirty (a measured leaf's content
//  changed, a style set) schedules a host relayout. Core types `onDirtied` as
//  `@Sendable`, so the host is reached through a `@unchecked Sendable` weak
//  relay that hops to the main thread; the closure captures neither the node
//  nor the view, and only weakly the host.
//

#if canImport(UIKit)
import UIKit
import ObjectiveC.runtime
import FlexboxCore

private enum FlexAssocKeys {
    nonisolated(unsafe) static var flexNode: UInt8 = 0
}

public extension UIView {

    /// The `FlexNode` this view renders, if it is managed by a `FlexHostView`.
    /// Read-only to consumers; the renderer owns the association. Held strong.
    /// Associated-object access is thread-safe at the ObjC runtime level, hence
    /// `nonisolated`.
    nonisolated internal(set) var flexNode: FlexNode? {
        get {
            objc_getAssociatedObject(self, &FlexAssocKeys.flexNode) as? FlexNode
        }
        set {
            objc_setAssociatedObject(
                self, &FlexAssocKeys.flexNode, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

/// Weak, main-hopping bridge from an engine `onDirtied` callback to the host.
/// `@unchecked Sendable`: it carries only a `weak` reference and only touches
/// UIKit on the main thread.
final class WeakHostRelay: @unchecked Sendable {
    private weak var host: FlexHostView?
    init(_ host: FlexHostView) { self.host = host }

    func fire() {
        if Thread.isMainThread {
            MainActor.assumeIsolated { host?.flexScheduleRelayout() }
        } else {
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.host?.flexScheduleRelayout() }
            }
        }
    }
}

enum NodeViewAssociation {

    /// Links `view` and `node`, and points `node.onDirtied` at `host`.
    @MainActor
    static func link(view: UIView, node: FlexNode, host: FlexHostView) {
        view.flexNode = node
        let relay = WeakHostRelay(host)
        node.onDirtied = { relay.fire() }
    }

    /// Breaks the link before a view/node pair is discarded.
    @MainActor
    static func unlink(view: UIView?, node: FlexNode) {
        node.onDirtied = nil
        view?.flexNode = nil
    }
}
#endif
