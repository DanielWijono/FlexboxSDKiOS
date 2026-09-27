//
//  FlexCells.swift
//  FlexboxKit
//
//  Self-sizing cells (spec Artefak 3 §"Self-sizing sel"). Each owns a
//  `FlexHostView` pinned to its `contentView` and hands the cell's sizing query
//  straight to that host.
//
//  Why the hand-off is needed: when a table / collection view sizes a cell it
//  solves the content view's constraints without ever laying out the host, so
//  `FlexHostView.intrinsicContentSize` is asked at width 0 and reports the
//  unwrapped height. Routing the fitting call to the host gives Yoga the real
//  width instead.
//
//  Usage: dequeue, then `cell.host.update(to: tree)`. Do not add other subviews
//  to `contentView` — the host's measurement is the cell's size.
//
//  EXPERIMENTAL API (until Artefak 4).
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

private func flexPinnedHost(in contentView: UIView) -> FlexHostView {
    let host = FlexHostView(tree: LayoutTree(id: "flex-cell-empty", content: .container))
    host.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(host)
    NSLayoutConstraint.activate([
        host.topAnchor.constraint(equalTo: contentView.topAnchor),
        host.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        host.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        host.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    ])
    return host
}

/// A `UITableViewCell` whose height is the flex content's height at the row's
/// width. Use with `rowHeight = UITableView.automaticDimension`.
open class FlexTableViewCell: UITableViewCell {

    /// The host rendering this cell's layout. Call `update(to:)` on it.
    public private(set) lazy var host: FlexHostView = flexPinnedHost(in: contentView)

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        _ = host
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        _ = host
    }

    open override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        host.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority
        )
    }
}

/// A `UICollectionViewCell` whose height is the flex content's height at the
/// width the layout proposes. The layout owns the width: give it one (e.g.
/// `estimatedItemSize.width` on a flow layout, or a fractional width in a
/// compositional layout) and let the height be estimated.
open class FlexCollectionViewCell: UICollectionViewCell {

    /// The host rendering this cell's layout. Call `update(to:)` on it.
    public private(set) lazy var host: FlexHostView = flexPinnedHost(in: contentView)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        _ = host
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        _ = host
    }

    open override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let width = layoutAttributes.size.width
        let fitted = host.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        attributes.size = CGSize(width: width, height: fitted.height)
        return attributes
    }
}
#endif
