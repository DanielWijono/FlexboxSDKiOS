//
//  FlexStyle.swift
//  FlexboxCore
//
//  How one box lays itself out — a plain value. `Equatable`, `Codable`,
//  `Sendable`, no pointers (spec Artefak 2 §"Model data").
//
//  Every field is Optional. `nil` means "not specified": the field is absent
//  from JSON and Yoga's own default applies. This is what makes reconciliation
//  "apply only what changed" fall out for free, and it is the schema's answer
//  to `YGUndefined` (see `FlexDimension`).
//
//  Codable is compiler-synthesized: optionals encode via `encodeIfPresent`
//  (missing keys, small payloads) and decode ignores unknown keys.
//

public struct FlexStyle: Equatable, Codable, Sendable {

    // MARK: Flex container

    public var flexDirection: FlexDirectionValue?
    public var justifyContent: JustifyContentValue?
    public var alignItems: AlignValue?
    public var alignSelf: AlignValue?
    public var alignContent: AlignValue?
    public var flexWrap: FlexWrapValue?

    // MARK: Flex item

    public var flexGrow: Double?
    public var flexShrink: Double?
    public var flexBasis: FlexDimension?

    // MARK: Box

    public var width: FlexDimension?
    public var height: FlexDimension?
    public var minWidth: FlexDimension?
    public var minHeight: FlexDimension?
    public var maxWidth: FlexDimension?
    public var maxHeight: FlexDimension?
    public var aspectRatio: Double?

    // MARK: Spacing

    public var margin: Edges?
    public var padding: Edges?
    public var border: EdgeWidths?
    public var position: PositionValue?
    public var inset: Edges?
    public var gap: FlexDimension?
    public var rowGap: FlexDimension?
    public var columnGap: FlexDimension?

    // MARK: Rendering box model

    public var display: DisplayValue?
    public var overflow: OverflowValue?
    public var boxSizing: BoxSizingValue?

    public init(
        flexDirection: FlexDirectionValue? = nil,
        justifyContent: JustifyContentValue? = nil,
        alignItems: AlignValue? = nil,
        alignSelf: AlignValue? = nil,
        alignContent: AlignValue? = nil,
        flexWrap: FlexWrapValue? = nil,
        flexGrow: Double? = nil,
        flexShrink: Double? = nil,
        flexBasis: FlexDimension? = nil,
        width: FlexDimension? = nil,
        height: FlexDimension? = nil,
        minWidth: FlexDimension? = nil,
        minHeight: FlexDimension? = nil,
        maxWidth: FlexDimension? = nil,
        maxHeight: FlexDimension? = nil,
        aspectRatio: Double? = nil,
        margin: Edges? = nil,
        padding: Edges? = nil,
        border: EdgeWidths? = nil,
        position: PositionValue? = nil,
        inset: Edges? = nil,
        gap: FlexDimension? = nil,
        rowGap: FlexDimension? = nil,
        columnGap: FlexDimension? = nil,
        display: DisplayValue? = nil,
        overflow: OverflowValue? = nil,
        boxSizing: BoxSizingValue? = nil
    ) {
        self.flexDirection = flexDirection
        self.justifyContent = justifyContent
        self.alignItems = alignItems
        self.alignSelf = alignSelf
        self.alignContent = alignContent
        self.flexWrap = flexWrap
        self.flexGrow = flexGrow
        self.flexShrink = flexShrink
        self.flexBasis = flexBasis
        self.width = width
        self.height = height
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.aspectRatio = aspectRatio
        self.margin = margin
        self.padding = padding
        self.border = border
        self.position = position
        self.inset = inset
        self.gap = gap
        self.rowGap = rowGap
        self.columnGap = columnGap
        self.display = display
        self.overflow = overflow
        self.boxSizing = boxSizing
    }

    /// The empty style — every field unspecified.
    public static let empty = FlexStyle()

    public var isEmpty: Bool { self == FlexStyle.empty }
}
