//
//  LayoutDecoding.swift
//  FlexboxCore
//
//  The one entry point for turning bytes from a backend into a usable
//  `LayoutTree`. Every failure mode is a thrown error — nothing here can trap
//  or abort the process, in DEBUG or RELEASE (spec Artefak 2 §"Selesai bila").
//
//  Unknown keys anywhere in the payload are ignored, not fatal, so a newer
//  backend stays readable by an older app (spec §"Validasi payload").
//

import Foundation

/// Why a payload could not be decoded into a validated tree.
public enum LayoutDecodingError: Error, Equatable, Sendable {
    /// JSON was malformed or the shape did not match the schema.
    case malformed(String)
    /// `schemaVersion` is outside `[minimumSupported, current]`.
    case unsupportedVersion(found: Int, supported: ClosedRange<Int>)
    /// The tree parsed but failed structural validation.
    case invalid(LayoutValidationError)
}

public enum LayoutDecoding {

    /// Decodes and validates a payload.
    ///
    /// - Returns: a `LayoutTree` guaranteed to satisfy `limits` and
    ///   `LayoutValidation`.
    /// - Throws: `LayoutDecodingError` — never traps.
    public static func decode(
        _ data: Data,
        limits: LayoutLimits = .default,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> LayoutTree {
        let payload: LayoutPayload
        do {
            payload = try decoder.decode(LayoutPayload.self, from: data)
        } catch let error as DecodingError {
            throw LayoutDecodingError.malformed(Self.describe(error))
        } catch {
            throw LayoutDecodingError.malformed(String(describing: error))
        }

        guard LayoutSchema.supports(payload.schemaVersion) else {
            throw LayoutDecodingError.unsupportedVersion(
                found: payload.schemaVersion,
                supported: LayoutSchema.minimumSupported ... LayoutSchema.current
            )
        }

        do {
            try LayoutValidation.validate(payload.root, limits: limits)
        } catch let error as LayoutValidationError {
            throw LayoutDecodingError.invalid(error)
        }

        return payload.root
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .dataCorrupted(let context):
            return "corrupted: \(context.debugDescription)"
        case .keyNotFound(let key, _):
            return "missing key '\(key.stringValue)'"
        case .typeMismatch(let type, let context):
            return "type mismatch for \(type) at \(path(context))"
        case .valueNotFound(let type, let context):
            return "missing value of \(type) at \(path(context))"
        @unknown default:
            return "decoding failed"
        }
    }

    private static func path(_ context: DecodingError.Context) -> String {
        context.codingPath.map(\.stringValue).joined(separator: ".")
    }
}
