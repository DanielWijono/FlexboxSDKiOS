//
//  FlexStyleDiff.swift
//  FlexboxCore
//
//  Field-level diff of two `FlexStyle` values, so reconciliation applies only
//  what changed (spec Artefak 2 §"Rekonsiliasi": "Hanya properti yang berubah
//  yang diterapkan ke node").
//

/// One addressable field of `FlexStyle`.
public enum StyleField: String, CaseIterable, Sendable, Equatable {
    case flexDirection, justifyContent, alignItems, alignSelf, alignContent, flexWrap
    case flexGrow, flexShrink, flexBasis
    case width, height, minWidth, minHeight, maxWidth, maxHeight, aspectRatio
    case margin, padding, border, position, inset, gap, rowGap, columnGap
    case display, overflow, boxSizing
}

public struct FlexStyleDelta: Equatable, Sendable {
    /// New values for fields that changed to (or between) non-`nil` values.
    public var changed: FlexStyle
    /// Fields that changed from a value back to unspecified and must be reset
    /// to Yoga's default.
    public var cleared: Set<StyleField>

    public var isEmpty: Bool { changed.isEmpty && cleared.isEmpty }
}

public extension FlexStyle {
    /// The delta needed to turn `old` into `self`.
    func delta(from old: FlexStyle) -> FlexStyleDelta {
        var changed = FlexStyle.empty
        var cleared: Set<StyleField> = []

        func check<T: Equatable>(_ field: StyleField,
                                 _ oldValue: T?,
                                 _ newValue: T?,
                                 _ assign: (inout FlexStyle) -> Void) {
            guard oldValue != newValue else { return }
            if newValue == nil {
                cleared.insert(field)
            } else {
                assign(&changed)
            }
        }

        check(.flexDirection, old.flexDirection, flexDirection) { $0.flexDirection = self.flexDirection }
        check(.justifyContent, old.justifyContent, justifyContent) { $0.justifyContent = self.justifyContent }
        check(.alignItems, old.alignItems, alignItems) { $0.alignItems = self.alignItems }
        check(.alignSelf, old.alignSelf, alignSelf) { $0.alignSelf = self.alignSelf }
        check(.alignContent, old.alignContent, alignContent) { $0.alignContent = self.alignContent }
        check(.flexWrap, old.flexWrap, flexWrap) { $0.flexWrap = self.flexWrap }
        check(.flexGrow, old.flexGrow, flexGrow) { $0.flexGrow = self.flexGrow }
        check(.flexShrink, old.flexShrink, flexShrink) { $0.flexShrink = self.flexShrink }
        check(.flexBasis, old.flexBasis, flexBasis) { $0.flexBasis = self.flexBasis }
        check(.width, old.width, width) { $0.width = self.width }
        check(.height, old.height, height) { $0.height = self.height }
        check(.minWidth, old.minWidth, minWidth) { $0.minWidth = self.minWidth }
        check(.minHeight, old.minHeight, minHeight) { $0.minHeight = self.minHeight }
        check(.maxWidth, old.maxWidth, maxWidth) { $0.maxWidth = self.maxWidth }
        check(.maxHeight, old.maxHeight, maxHeight) { $0.maxHeight = self.maxHeight }
        check(.aspectRatio, old.aspectRatio, aspectRatio) { $0.aspectRatio = self.aspectRatio }
        check(.margin, old.margin, margin) { $0.margin = self.margin }
        check(.padding, old.padding, padding) { $0.padding = self.padding }
        check(.border, old.border, border) { $0.border = self.border }
        check(.position, old.position, position) { $0.position = self.position }
        check(.inset, old.inset, inset) { $0.inset = self.inset }
        check(.gap, old.gap, gap) { $0.gap = self.gap }
        check(.rowGap, old.rowGap, rowGap) { $0.rowGap = self.rowGap }
        check(.columnGap, old.columnGap, columnGap) { $0.columnGap = self.columnGap }
        check(.display, old.display, display) { $0.display = self.display }
        check(.overflow, old.overflow, overflow) { $0.overflow = self.overflow }
        check(.boxSizing, old.boxSizing, boxSizing) { $0.boxSizing = self.boxSizing }

        return FlexStyleDelta(changed: changed, cleared: cleared)
    }
}
