//
//  PropBinding.swift
//  FlexboxKit
//
//  Typed reads over a leaf's `PropBag` (`[String: JSONValue]`). One home for
//  prop parsing so the built-in factories stay small. Pure — no UIKit — so it
//  compiles and tests under `swift test`.
//
//  `props` is DATA ONLY (spec Pillar §"Batas terhadap kebijakan App Store"):
//  these readers return strings / numbers / bools / nested containers and
//  nothing that could be executed.
//

import FlexboxCore

/// A read-only view over a `PropBag?` with type-checked accessors. A missing key
/// or a wrong type yields `nil`, never a trap.
struct PropReader {
    let bag: PropBag?

    init(_ bag: PropBag?) { self.bag = bag }

    func string(_ key: String) -> String? {
        if case .string(let v)? = bag?[key] { return v }
        return nil
    }

    func double(_ key: String) -> Double? {
        if case .number(let v)? = bag?[key] { return v }
        return nil
    }

    func int(_ key: String) -> Int? {
        guard let d = double(key), d.isFinite else { return nil }
        return Int(d)
    }

    func bool(_ key: String) -> Bool? {
        if case .bool(let v)? = bag?[key] { return v }
        return nil
    }

    func object(_ key: String) -> [String: JSONValue]? {
        if case .object(let v)? = bag?[key] { return v }
        return nil
    }

    func array(_ key: String) -> [JSONValue]? {
        if case .array(let v)? = bag?[key] { return v }
        return nil
    }

    /// `true` iff the bag carries `key` at all (any type).
    func has(_ key: String) -> Bool { bag?[key] != nil }
}
