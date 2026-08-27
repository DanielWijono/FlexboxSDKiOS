//
//  FlexViewRegistry.swift
//  FlexboxKit
//
//  Maps a node's `ContentType` to the `FlexViewFactory` that renders it. Ships
//  with `container` / `text` / `image`; host apps register `.custom("name")`
//  factories to match `"content": "name"` in a payload, and may override a
//  built-in.
//
//  An unresolved content type is a rejected op, not a trap: the renderer
//  substitutes a plain container so the rest of the screen still renders (spec
//  Pillar §"Tidak boleh ada assert fatal").
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

@MainActor
public struct FlexViewRegistry {

    private var factories: [String: FlexViewFactory]

    private init(factories: [String: FlexViewFactory]) {
        self.factories = factories
    }

    /// The built-in registry: `container` → plain view, `text` → label,
    /// `image` → image view.
    public static var `default`: FlexViewRegistry {
        FlexViewRegistry(factories: [
            ContentType.container.registryKey: ContainerViewFactory(),
            ContentType.text.registryKey: TextViewFactory(),
            ContentType.image.registryKey: ImageViewFactory(),
        ])
    }

    /// Registers (or replaces) the factory for `content`.
    public mutating func register(_ factory: FlexViewFactory, for content: ContentType) {
        factories[content.registryKey] = factory
    }

    /// Registers a factory that only creates a view (no `props` update, no
    /// self-measurement) for `content`.
    public mutating func register(
        _ content: ContentType,
        make: @escaping (LayoutTree) -> UIView
    ) {
        factories[content.registryKey] = ClosureViewFactory(make: make)
    }

    /// The factory for `content`, if one is registered.
    func factory(for content: ContentType) -> FlexViewFactory? {
        factories[content.registryKey]
    }
}

extension ContentType {
    /// The `FlexViewRegistry` dictionary key for this content type — the same
    /// string it encodes to in JSON.
    var registryKey: String {
        switch self {
        case .container: return "container"
        case .text: return "text"
        case .image: return "image"
        case .custom(let name): return name
        }
    }
}
#endif
