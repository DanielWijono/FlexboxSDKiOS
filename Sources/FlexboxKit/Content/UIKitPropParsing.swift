//
//  UIKitPropParsing.swift
//  FlexboxKit
//
//  UIKit-typed reads layered on `PropReader` (the pure scalar reader). Colours,
//  fonts and the small UIKit enums the built-in factories need. Still data only
//  — a string names a colour, an object describes a font; nothing is executed.
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

extension PropReader {

    /// A colour from `"#RGB"`, `"#RRGGBB"` or `"#RRGGBBAA"` (the leading `#` is
    /// optional). `nil` on anything else.
    func color(_ key: String) -> UIColor? {
        guard let raw = string(key) else { return nil }
        return UIColor(flexHex: raw)
    }

    /// A font from an object: `{ "size": 17, "weight": "semibold", "name": "..." }`.
    /// `name` wins if present; otherwise the system font at `weight` (default
    /// `.regular`). `size` defaults to the label's current point size via `base`.
    func font(_ key: String, base: UIFont) -> UIFont? {
        guard let obj = object(key) else { return nil }
        let reader = PropReader(obj)
        let size: CGFloat = reader.double("size").map { CGFloat($0) } ?? base.pointSize
        if let name = reader.string("name"), let named = UIFont(name: name, size: size) {
            return named
        }
        let weight = UIKitPropMaps.fontWeight(reader.string("weight"))
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    func textAlignment(_ key: String) -> NSTextAlignment? {
        UIKitPropMaps.textAlignment(string(key))
    }

    func lineBreakMode(_ key: String) -> NSLineBreakMode? {
        UIKitPropMaps.lineBreakMode(string(key))
    }

    func contentMode(_ key: String) -> UIView.ContentMode? {
        UIKitPropMaps.contentMode(string(key))
    }
}

enum UIKitPropMaps {

    static func fontWeight(_ raw: String?) -> UIFont.Weight {
        switch raw {
        case "ultraLight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular", nil: return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }

    static func textAlignment(_ raw: String?) -> NSTextAlignment? {
        switch raw {
        case "left": return .left
        case "center": return .center
        case "right": return .right
        case "justified": return .justified
        case "natural": return .natural
        default: return nil
        }
    }

    static func lineBreakMode(_ raw: String?) -> NSLineBreakMode? {
        switch raw {
        case "byWordWrapping": return .byWordWrapping
        case "byCharWrapping": return .byCharWrapping
        case "byClipping": return .byClipping
        case "byTruncatingHead": return .byTruncatingHead
        case "byTruncatingTail": return .byTruncatingTail
        case "byTruncatingMiddle": return .byTruncatingMiddle
        default: return nil
        }
    }

    static func contentMode(_ raw: String?) -> UIView.ContentMode? {
        switch raw {
        case "scaleToFill": return .scaleToFill
        case "scaleAspectFit": return .scaleAspectFit
        case "scaleAspectFill": return .scaleAspectFill
        case "center": return .center
        case "top": return .top
        case "bottom": return .bottom
        case "left": return .left
        case "right": return .right
        default: return nil
        }
    }
}

extension UIColor {

    /// Parses `"#RGB"`, `"#RRGGBB"`, `"#RRGGBBAA"` (leading `#` optional).
    convenience init?(flexHex raw: String) {
        var s = Substring(raw)
        if s.first == "#" { s = s.dropFirst() }
        guard s.allSatisfy(\.isHexDigit) else { return nil }

        let hex = String(s)
        func byte(_ start: Int, _ len: Int) -> CGFloat? {
            let a = hex.index(hex.startIndex, offsetBy: start)
            let b = hex.index(a, offsetBy: len)
            guard let v = Int(hex[a..<b], radix: 16) else { return nil }
            return len == 1 ? CGFloat(v) / 15.0 : CGFloat(v) / 255.0
        }

        switch hex.count {
        case 3:
            guard let r = byte(0, 1), let g = byte(1, 1), let b = byte(2, 1) else { return nil }
            self.init(red: r, green: g, blue: b, alpha: 1)
        case 6:
            guard let r = byte(0, 2), let g = byte(2, 2), let b = byte(4, 2) else { return nil }
            self.init(red: r, green: g, blue: b, alpha: 1)
        case 8:
            guard let r = byte(0, 2), let g = byte(2, 2), let b = byte(4, 2), let a = byte(6, 2)
            else { return nil }
            self.init(red: r, green: g, blue: b, alpha: a)
        default:
            return nil
        }
    }
}
#endif
