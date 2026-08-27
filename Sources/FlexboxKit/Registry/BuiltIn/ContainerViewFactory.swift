//
//  ContainerViewFactory.swift
//  FlexboxKit
//
//  The `container` content type: a plain `UIView` that only positions children.
//  It never measures itself — its size comes entirely from the flex layout.
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

struct ContainerViewFactory: FlexViewFactory {

    func makeView(for tree: LayoutTree) -> UIView {
        let view = UIView()
        view.clipsToBounds = (tree.style.overflow == .hidden || tree.style.overflow == .scroll)
        return view
    }

    func update(_ view: UIView, for tree: LayoutTree) {
        view.clipsToBounds = (tree.style.overflow == .hidden || tree.style.overflow == .scroll)
    }

    // measure: inherits the protocol default (nil) — containers do not
    // self-size in a normal layout pass.
}
#endif
