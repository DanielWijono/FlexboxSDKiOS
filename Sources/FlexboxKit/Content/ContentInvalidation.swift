//
//  ContentInvalidation.swift
//  FlexboxKit
//
//  When a pushed update changes a leaf's `props`, only *some* of those keys feed
//  the factory's `measure(...)`. Changing `text` or `image` must re-measure the
//  node; changing `textColor` or `tintColor` must not — a needless
//  `markContentDirty()` re-measures that leaf (and dirties its ancestors) every
//  pass for a purely cosmetic change (spec Artefak 3 §"Invalidasi konten").
//
//  Pure — no UIKit — so it also compiles and is unit-tested under `swift test`
//  on macOS.
//

import FlexboxCore

enum ContentInvalidation {

    /// The `props` keys a built-in factory reads inside `measure(...)`.
    ///
    /// - `.container` never measures itself → empty set.
    /// - `.custom` is opaque here → `nil`, meaning "assume any change matters".
    static func sizeAffectingKeys(for content: ContentType) -> Set<String>? {
        switch content {
        case .container:
            return []
        case .text:
            return ["text", "attributedText", "font", "numberOfLines", "lineBreakMode"]
        case .image:
            return ["image", "systemImage"]
        case .custom:
            return nil
        }
    }

    /// `true` if moving from `old` to `new` props can change the node's measured
    /// size for `content`.
    static func requiresRemeasure(
        content: ContentType,
        old: PropBag?,
        new: PropBag?
    ) -> Bool {
        guard let keys = sizeAffectingKeys(for: content) else {
            return old != new  // custom content: conservative
        }
        if keys.isEmpty { return false }
        return keys.contains { old?[$0] != new?[$0] }
    }
}
