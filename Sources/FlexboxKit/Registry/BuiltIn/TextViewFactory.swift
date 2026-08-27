//
//  TextViewFactory.swift
//  FlexboxKit
//
//  The `text` content type: a `UILabel`. v1 is `UILabel` only — no `UITextView`
//  fallback for rich text yet.
//
//  Recognised `props`: `text`, `attributedText` (plain string for now),
//  `font` (object), `textColor`, `numberOfLines`, `textAlignment`,
//  `lineBreakMode`.
//
//  Size-affecting keys (`text`, `attributedText`, `font`, `numberOfLines`) are
//  what `ContentInvalidation` watches to fire `markContentDirty()`.
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

struct TextViewFactory: FlexViewFactory {

    func makeView(for tree: LayoutTree) -> UIView {
        let label = UILabel()
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        apply(tree, to: label)
        return label
    }

    func update(_ view: UIView, for tree: LayoutTree) {
        guard let label = view as? UILabel else { return }
        apply(tree, to: label)
    }

    func measure(
        _ view: UIView,
        width: FlexMeasureConstraint,
        height: FlexMeasureConstraint
    ) -> FlexSize? {
        guard let label = view as? UILabel else { return nil }

        let request = flexMeasureRequest(width: width, height: height)
        // A wrapping label needs its wrap width set before `sizeThatFits`.
        label.preferredMaxLayoutWidth = request.width.isFinite ? request.width : 0
        let fitted = label.sizeThatFits(request)
        return flexClamp(fitted: fitted, width: width, height: height)
    }

    // MARK: -

    private func apply(_ tree: LayoutTree, to label: UILabel) {
        let props = PropReader(tree.props)

        if let s = props.string("attributedText") ?? props.string("text") {
            label.text = s
        } else {
            label.text = nil
        }
        if let font = props.font("font", base: label.font ?? UIFont.preferredFont(forTextStyle: .body)) {
            label.font = font
        }
        if let color = props.color("textColor") {
            label.textColor = color
        }
        if let lines = props.int("numberOfLines") {
            label.numberOfLines = max(0, lines)
        }
        if let alignment = props.textAlignment("textAlignment") {
            label.textAlignment = alignment
        }
        if let mode = props.lineBreakMode("lineBreakMode") {
            label.lineBreakMode = mode
        }
    }
}
#endif
