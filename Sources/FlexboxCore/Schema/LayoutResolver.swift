//
//  LayoutResolver.swift
//  FlexboxCore
//
//  Spec Pillar §"Tata letak cadangan": a screen must never be blank because a
//  layout file is broken. This turns "remote bytes + a bundled fallback" into a
//  single decision, and reports via `FlexTelemetry` whenever the fallback wins
//  (Pillar §Observabilitas: "berapa kali cadangan terpakai").
//
//  The per-screen bundling of fallback assets is the app's job (spec Artefak 4);
//  the decision and the hook live here.
//

import Foundation

/// Why the bundled fallback was chosen over the remote payload.
public enum FallbackReason: Equatable, Sendable, CustomStringConvertible {
    case noRemoteData
    case parseFailed(String)
    case unsupportedVersion(found: Int)
    case validationFailed(LayoutValidationError)

    public var description: String {
        switch self {
        case .noRemoteData: return "noRemoteData"
        case .parseFailed(let detail): return "parseFailed(\(detail))"
        case .unsupportedVersion(let found): return "unsupportedVersion(\(found))"
        case .validationFailed(let error): return "validationFailed(\(error))"
        }
    }
}

/// The layout a screen should actually use.
public enum LayoutResolution: Equatable, Sendable {
    case remote(LayoutTree)
    case fallback(LayoutTree, reason: FallbackReason)

    /// The tree to build, whichever source it came from.
    public var tree: LayoutTree {
        switch self {
        case .remote(let tree), .fallback(let tree, _): return tree
        }
    }

    public var usedFallback: Bool {
        if case .fallback = self { return true }
        return false
    }
}

public enum LayoutResolver {

    /// Chooses between a remote payload and a bundled fallback.
    ///
    /// The `fallback` tree is assumed to be trusted (it shipped in the app) and
    /// is not re-validated. If `remote` is present and decodes and validates,
    /// it wins; otherwise the fallback is returned with a reason and a
    /// telemetry event is emitted.
    public static func resolve(
        remote data: Data?,
        fallback: LayoutTree,
        limits: LayoutLimits = .default,
        decoder: JSONDecoder = JSONDecoder()
    ) -> LayoutResolution {
        guard let data else {
            return fell(back: fallback, .noRemoteData)
        }
        do {
            let tree = try LayoutDecoding.decode(data, limits: limits, decoder: decoder)
            return .remote(tree)
        } catch let LayoutDecodingError.unsupportedVersion(found, _) {
            return fell(back: fallback, .unsupportedVersion(found: found))
        } catch let LayoutDecodingError.invalid(error) {
            return fell(back: fallback, .validationFailed(error))
        } catch let LayoutDecodingError.malformed(detail) {
            return fell(back: fallback, .parseFailed(detail))
        } catch {
            return fell(back: fallback, .parseFailed(String(describing: error)))
        }
    }

    private static func fell(back tree: LayoutTree, _ reason: FallbackReason) -> LayoutResolution {
        FlexTelemetry.usedFallback(reason.description)
        return .fallback(tree, reason: reason)
    }
}
