//
//  YogaDefaults.swift
//  FlexboxCore
//
//  Explicit values for "reset this field to Yoga's default", used when a
//  reconciliation delta CLEARS a field (value → unspecified). Yoga has no
//  generic per-field unset, so the default is written back explicitly.
//
//  Dimensions, grow/shrink, gap and edge values reset precisely. Enum fields
//  reset to Yoga 3.x documented defaults. See SCHEMA.md.
//

public extension FlexStyle {
    /// A style whose `fields` are set to Yoga's default and everything else is
    /// left unspecified. Applying it re-establishes the defaults for exactly
    /// those fields.
    static func resetting(_ fields: Set<StyleField>) -> FlexStyle {
        var s = FlexStyle.empty
        for field in fields {
            switch field {
            case .flexDirection: s.flexDirection = .column
            case .justifyContent: s.justifyContent = .flexStart
            case .alignItems: s.alignItems = .stretch
            case .alignSelf: s.alignSelf = .auto
            case .alignContent: s.alignContent = .flexStart
            case .flexWrap: s.flexWrap = .noWrap
            case .flexGrow: s.flexGrow = 0
            case .flexShrink: s.flexShrink = 0
            case .flexBasis: s.flexBasis = .auto
            case .width: s.width = .auto
            case .height: s.height = .auto
            case .minWidth: s.minWidth = .points(0)
            case .minHeight: s.minHeight = .points(0)
            // Yoga has no "no maximum" setter; approximate with a large finite
            // value. Precise unset of min/max/aspectRatio is a known limitation
            // (SCHEMA.md) — avoid clearing these in payloads for now.
            case .maxWidth: s.maxWidth = .points(1_000_000)
            case .maxHeight: s.maxHeight = .points(1_000_000)
            case .aspectRatio: s.aspectRatio = nil
            case .margin: s.margin = Edges(.points(0))
            case .padding: s.padding = Edges(.points(0))
            case .border: s.border = EdgeWidths(0)
            case .position: s.position = .relative
            case .inset: s.inset = Edges(.points(0))
            case .gap: s.gap = .points(0)
            case .rowGap: s.rowGap = .points(0)
            case .columnGap: s.columnGap = .points(0)
            case .display: s.display = .flex
            case .overflow: s.overflow = .visible
            case .boxSizing: s.boxSizing = .borderBox
            }
        }
        return s
    }
}
