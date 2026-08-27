//
//  ImageViewFactory.swift
//  FlexboxKit
//
//  The `image` content type: a `UIImageView`.
//
//  Recognised `props`: `image` (asset name in the main bundle), `systemImage`
//  (SF Symbol name), `contentMode`, `tintColor`.
//
//  Measurement returns the image's own point size, clamped to the constraints.
//  A node with an explicit `width`/`height` in its style never reaches here.
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

struct ImageViewFactory: FlexViewFactory {

    func makeView(for tree: LayoutTree) -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        apply(tree, to: imageView)
        return imageView
    }

    func update(_ view: UIView, for tree: LayoutTree) {
        guard let imageView = view as? UIImageView else { return }
        apply(tree, to: imageView)
    }

    func measure(
        _ view: UIView,
        width: FlexMeasureConstraint,
        height: FlexMeasureConstraint
    ) -> FlexSize? {
        guard let imageView = view as? UIImageView else { return nil }
        let natural = imageView.image?.size ?? .zero
        return flexClamp(fitted: natural, width: width, height: height)
    }

    // MARK: -

    private func apply(_ tree: LayoutTree, to imageView: UIImageView) {
        let props = PropReader(tree.props)

        if let name = props.string("image") {
            imageView.image = UIImage(named: name)
        } else if let symbol = props.string("systemImage") {
            imageView.image = UIImage(systemName: symbol)
        } else {
            imageView.image = nil
        }
        if let mode = props.contentMode("contentMode") {
            imageView.contentMode = mode
        }
        if let tint = props.color("tintColor") {
            imageView.tintColor = tint
        }
    }
}
#endif
