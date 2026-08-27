//
//  StyleEnums.swift
//  FlexboxCore
//
//  The enumerated style values. Each is `String`-backed with CSS-flexbox
//  spellings (`"flex-start"`, `"space-between"`, `"row-reverse"`) so payloads
//  read naturally and match React Native / web intuition.
//
//  Unknown strings fail decoding of that single value; callers decide whether
//  that falls the whole payload back (see `LayoutResolver`).
//

public enum FlexDirectionValue: String, Codable, Sendable, CaseIterable {
    case row
    case rowReverse = "row-reverse"
    case column
    case columnReverse = "column-reverse"
}

public enum JustifyContentValue: String, Codable, Sendable, CaseIterable {
    case flexStart = "flex-start"
    case center
    case flexEnd = "flex-end"
    case spaceBetween = "space-between"
    case spaceAround = "space-around"
    case spaceEvenly = "space-evenly"
}

public enum AlignValue: String, Codable, Sendable, CaseIterable {
    case auto
    case flexStart = "flex-start"
    case center
    case flexEnd = "flex-end"
    case stretch
    case baseline
    case spaceBetween = "space-between"
    case spaceAround = "space-around"
    case spaceEvenly = "space-evenly"
}

public enum FlexWrapValue: String, Codable, Sendable, CaseIterable {
    case noWrap = "nowrap"
    case wrap
    case wrapReverse = "wrap-reverse"
}

public enum PositionValue: String, Codable, Sendable, CaseIterable {
    case relative
    case absolute
    case staticPosition = "static"
}

public enum DisplayValue: String, Codable, Sendable, CaseIterable {
    case flex
    case none
    case contents
}

public enum OverflowValue: String, Codable, Sendable, CaseIterable {
    case visible
    case hidden
    case scroll
}

public enum BoxSizingValue: String, Codable, Sendable, CaseIterable {
    case borderBox = "border-box"
    case contentBox = "content-box"
}
