//
//  FlexboxKit.swift
//
//  Placeholder for the UIKit renderer (spec Artefak 3). Intentionally empty in
//  this pass beyond a version marker. The renderer — view registry, measure
//  functions against `sizeThatFits`, `layoutSubviews` trigger, scroll content
//  sizing, Auto Layout coexistence — lands in a later pass.
//

#if canImport(UIKit)
import UIKit
#endif

/// SDK version marker. Kept here so `import FlexboxKit` links cleanly before the
/// renderer exists.
public enum FlexboxKit {
    public static let placeholder = true
}
