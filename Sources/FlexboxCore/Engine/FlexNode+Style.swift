//
//  FlexNode+Style.swift
//  FlexboxCore
//
//  Bridge from the value model (`FlexStyle`) to a live Yoga node. Only fields
//  that are non-`nil` are written; a `nil` field leaves Yoga's own default in
//  place (spec Artefak 2 §"Model data").
//
//  Style setters do NOT call `YGNodeMarkDirty` — Yoga dirties itself on a style
//  change (spec §Invalidasi). Only external content changes need
//  `markContentDirty()`.
//

extension FlexNode {

    /// Applies every specified field of `style` to this node. Unspecified
    /// (`nil`) fields are left untouched.
    public func apply(_ style: FlexStyle) {
        applyContainer(style)
        applyItem(style)
        applyBox(style)
        applySpacing(style)
        applyBoxModel(style)
    }

    /// Applies a reconciliation delta: writes changed fields and resets cleared
    /// fields to Yoga defaults (spec Artefak 2 §"Rekonsiliasi").
    public func applyDelta(_ delta: FlexStyleDelta) {
        if !delta.cleared.isEmpty {
            apply(FlexStyle.resetting(delta.cleared))
        }
        if !delta.changed.isEmpty {
            apply(delta.changed)
        }
    }

    // MARK: Container

    private func applyContainer(_ s: FlexStyle) {
        if let v = s.flexDirection {
            switch v {
            case .row: yoga_setFlexDirection(handle, .row)
            case .rowReverse: yoga_setFlexDirection(handle, .rowReverse)
            case .column: yoga_setFlexDirection(handle, .column)
            case .columnReverse: yoga_setFlexDirection(handle, .columnReverse)
            }
        }
        if let v = s.justifyContent {
            switch v {
            case .flexStart: yoga_setJustifyContent(handle, .flexStart)
            case .center: yoga_setJustifyContent(handle, .center)
            case .flexEnd: yoga_setJustifyContent(handle, .flexEnd)
            case .spaceBetween: yoga_setJustifyContent(handle, .spaceBetween)
            case .spaceAround: yoga_setJustifyContent(handle, .spaceAround)
            case .spaceEvenly: yoga_setJustifyContent(handle, .spaceEvenly)
            }
        }
        if let v = s.alignItems { yoga_setAlignItems(handle, mapAlign(v)) }
        if let v = s.alignSelf { yoga_setAlignSelf(handle, mapAlign(v)) }
        if let v = s.alignContent { yoga_setAlignContent(handle, mapAlign(v)) }
        if let v = s.flexWrap {
            switch v {
            case .noWrap: yoga_setFlexWrap(handle, .noWrap)
            case .wrap: yoga_setFlexWrap(handle, .wrap)
            case .wrapReverse: yoga_setFlexWrap(handle, .wrapReverse)
            }
        }
    }

    private func mapAlign(_ v: AlignValue) -> YAlign {
        switch v {
        case .auto: return .auto
        case .flexStart: return .flexStart
        case .center: return .center
        case .flexEnd: return .flexEnd
        case .stretch: return .stretch
        case .baseline: return .baseline
        case .spaceBetween: return .spaceBetween
        case .spaceAround: return .spaceAround
        case .spaceEvenly: return .spaceEvenly
        }
    }

    // MARK: Item

    private func applyItem(_ s: FlexStyle) {
        if let v = s.flexGrow { yoga_setFlexGrow(handle, v) }
        if let v = s.flexShrink { yoga_setFlexShrink(handle, v) }
        if let v = s.flexBasis {
            switch v {
            case .points(let p): yoga_setFlexBasisPoint(handle, p)
            case .percent(let p): yoga_setFlexBasisPercent(handle, p)
            case .auto: yoga_setFlexBasisAuto(handle)
            }
        }
        if let v = s.aspectRatio { yoga_setAspectRatio(handle, v) }
    }

    // MARK: Box

    private func applyBox(_ s: FlexStyle) {
        apply(dimension: s.width,
              point: yoga_setWidthPoint, percent: yoga_setWidthPercent, auto: yoga_setWidthAuto)
        apply(dimension: s.height,
              point: yoga_setHeightPoint, percent: yoga_setHeightPercent, auto: yoga_setHeightAuto)
        apply(dimension: s.minWidth,
              point: yoga_setMinWidthPoint, percent: yoga_setMinWidthPercent, auto: nil)
        apply(dimension: s.minHeight,
              point: yoga_setMinHeightPoint, percent: yoga_setMinHeightPercent, auto: nil)
        apply(dimension: s.maxWidth,
              point: yoga_setMaxWidthPoint, percent: yoga_setMaxWidthPercent, auto: nil)
        apply(dimension: s.maxHeight,
              point: yoga_setMaxHeightPoint, percent: yoga_setMaxHeightPercent, auto: nil)
    }

    private func apply(
        dimension: FlexDimension?,
        point: (YogaNodeHandle, Double) -> Void,
        percent: (YogaNodeHandle, Double) -> Void,
        auto: ((YogaNodeHandle) -> Void)?
    ) {
        guard let dimension else { return }
        switch dimension {
        case .points(let v): point(handle, v)
        case .percent(let v): percent(handle, v)
        case .auto: auto?(handle)
        }
    }

    // MARK: Spacing

    private func applySpacing(_ s: FlexStyle) {
        if let m = s.margin { applyEdges(m, kind: .margin) }
        if let p = s.padding { applyEdges(p, kind: .padding) }
        if let i = s.inset { applyEdges(i, kind: .position) }
        if let b = s.border { applyBorder(b) }

        if let g = s.gap { applyGap(g, gutter: .all) }
        if let g = s.rowGap { applyGap(g, gutter: .row) }
        if let g = s.columnGap { applyGap(g, gutter: .column) }
    }

    private enum EdgeKind { case margin, padding, position }

    private func applyEdges(_ edges: Edges, kind: EdgeKind) {
        let pairs: [(YEdge, FlexDimension?)] = [
            (.all, edges.all), (.horizontal, edges.horizontal), (.vertical, edges.vertical),
            (.top, edges.top), (.bottom, edges.bottom), (.left, edges.left), (.right, edges.right),
            (.start, edges.start), (.end, edges.end),
        ]
        for (edge, dim) in pairs {
            guard let dim else { continue }
            switch (kind, dim) {
            case (.margin, .points(let v)): yoga_setMarginPoint(handle, edge, v)
            case (.margin, .percent(let v)): yoga_setMarginPercent(handle, edge, v)
            case (.margin, .auto): yoga_setMarginAuto(handle, edge)
            case (.padding, .points(let v)): yoga_setPaddingPoint(handle, edge, v)
            case (.padding, .percent(let v)): yoga_setPaddingPercent(handle, edge, v)
            case (.padding, .auto): break // padding has no "auto"
            case (.position, .points(let v)): yoga_setPositionPoint(handle, edge, v)
            case (.position, .percent(let v)): yoga_setPositionPercent(handle, edge, v)
            case (.position, .auto): break
            }
        }
    }

    private func applyBorder(_ b: EdgeWidths) {
        let pairs: [(YEdge, Double?)] = [
            (.all, b.all), (.horizontal, b.horizontal), (.vertical, b.vertical),
            (.top, b.top), (.bottom, b.bottom), (.left, b.left), (.right, b.right),
            (.start, b.start), (.end, b.end),
        ]
        for (edge, width) in pairs {
            guard let width else { continue }
            yoga_setBorderPoint(handle, edge, width)
        }
    }

    private func applyGap(_ dim: FlexDimension, gutter: YGutter) {
        switch dim {
        case .points(let v): yoga_setGapPoint(handle, gutter, v)
        case .percent(let v): yoga_setGapPercent(handle, gutter, v)
        case .auto: break
        }
    }

    // MARK: Rendering box model

    private func applyBoxModel(_ s: FlexStyle) {
        if let v = s.position {
            switch v {
            case .relative: yoga_setPositionType(handle, .relative)
            case .absolute: yoga_setPositionType(handle, .absolute)
            case .staticPosition: yoga_setPositionType(handle, .staticPosition)
            }
        }
        if let v = s.display {
            switch v {
            case .flex: yoga_setDisplay(handle, .flex)
            case .none: yoga_setDisplay(handle, .none)
            case .contents: yoga_setDisplay(handle, .contents)
            }
        }
        if let v = s.overflow {
            switch v {
            case .visible: yoga_setOverflow(handle, .visible)
            case .hidden: yoga_setOverflow(handle, .hidden)
            case .scroll: yoga_setOverflow(handle, .scroll)
            }
        }
        if let v = s.boxSizing {
            switch v {
            case .borderBox: yoga_setBoxSizing(handle, .borderBox)
            case .contentBox: yoga_setBoxSizing(handle, .contentBox)
            }
        }
    }
}
