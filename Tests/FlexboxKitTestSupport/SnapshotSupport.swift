//
//  SnapshotSupport.swift
//  FlexboxKitTestSupport
//
//  Renders a `FlexHostView` to a PNG and diffs it against a committed reference
//  image next to the calling test file (`__Snapshots__/<name>.png`).
//
//    - No reference on disk, or `FLEX_RECORD_SNAPSHOTS=1` in the environment:
//      the PNG is written and the test fails with "recorded" — open it, and if
//      it looks right, re-run (now it passes and guards against regressions).
//    - Reference present: the two images are compared pixel-for-pixel with a
//      small tolerance; on mismatch a `<name>.failure.png` is written beside the
//      reference and the test fails.
//
//  iOS Simulator only. Rendering uses `CALayer.render(in:)`, which is
//  deterministic headless (no window server, no run-loop spin needed).
//

#if canImport(UIKit)
import UIKit
import XCTest
import FlexboxKit
import FlexboxCore

public enum FlexSnapshot {

    /// Fixed render scale so a reference PNG has the same pixel dimensions on any
    /// simulator (a 320×240 point capture is always 640×480 px).
    public static let scale: CGFloat = 2

    /// Mounts `host` at `size`, lays it out once, and returns a PNG of the result.
    @MainActor
    public static func png(_ host: FlexHostView, size: CGSize) -> Data {
        let mounted = HostHarness.finishMount(host: host, size: size)
        defer { mounted.window.resignKey() }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(
            bounds: CGRect(origin: .zero, size: size), format: format
        )
        let image = renderer.image { ctx in
            host.layer.render(in: ctx.cgContext)
        }
        guard let data = image.pngData() else {
            preconditionFailure("FlexSnapshot: could not encode PNG")
        }
        return data
    }

    /// Verifies `host`'s rendering against `__Snapshots__/<name>.png` next to the
    /// test file. See the file header for record vs. compare behaviour.
    @MainActor
    public static func verify(
        _ host: FlexHostView,
        named name: String,
        size: CGSize,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let data = png(host, size: size)
        let dir = directory(for: file)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let reference = dir.appendingPathComponent("\(name).png")

        let recording = ProcessInfo.processInfo.environment["FLEX_RECORD_SNAPSHOTS"] == "1"
        guard !recording, let existing = try? Data(contentsOf: reference) else {
            try? data.write(to: reference)
            XCTFail(
                "Recorded snapshot → \(reference.path)\nOpen it; if it looks right, re-run.",
                file: file, line: line
            )
            return
        }

        if let reason = pixelDiff(existing, data) {
            let failure = dir.appendingPathComponent("\(name).failure.png")
            try? data.write(to: failure)
            XCTFail(
                "Snapshot \"\(name)\" changed (\(reason)).\nNew image → \(failure.path)\n"
                    + "Re-record with FLEX_RECORD_SNAPSHOTS=1 once the change is intentional.",
                file: file, line: line
            )
        }
    }

    /// Asserts that `a` and `b` render to the same pixels at `size` — used to
    /// prove an incremental `update(to:)` converges on the same result as a
    /// freshly built host for the same tree.
    @MainActor
    public static func assertSameRender(
        _ a: FlexHostView,
        _ b: FlexHostView,
        size: CGSize,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if let reason = pixelDiff(png(a, size: size), png(b, size: size), tolerance: 0) {
            XCTFail("renders differ (\(reason))", file: file, line: line)
        }
    }

    // MARK: - Internals

    static func directory(for file: StaticString) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
    }

    /// `nil` when the two PNGs decode to buffers that match within tolerance,
    /// otherwise a short human-readable reason.
    static func pixelDiff(_ lhs: Data, _ rhs: Data, tolerance: Double = 0.02) -> String? {
        guard
            let a = UIImage(data: lhs)?.cgImage,
            let b = UIImage(data: rhs)?.cgImage
        else { return "one image would not decode" }

        guard a.width == b.width, a.height == b.height else {
            return "size \(a.width)×\(a.height) vs \(b.width)×\(b.height)"
        }

        let width = a.width, height = a.height
        let bytesPerRow = width * 4
        let count = bytesPerRow * height
        var bufA = [UInt8](repeating: 0, count: count)
        var bufB = [UInt8](repeating: 0, count: count)
        let space = CGColorSpaceCreateDeviceRGB()
        let bitmap = CGImageAlphaInfo.premultipliedLast.rawValue

        func draw(_ image: CGImage, into buffer: inout [UInt8]) {
            buffer.withUnsafeMutableBytes { raw in
                CGContext(
                    data: raw.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                    space: space, bitmapInfo: bitmap
                )?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }
        draw(a, into: &bufA)
        draw(b, into: &bufB)

        var differing = 0
        for i in 0 ..< count where abs(Int(bufA[i]) - Int(bufB[i])) > 8 {
            differing += 1
        }
        let ratio = Double(differing) / Double(count)
        return ratio > tolerance
            ? String(format: "%.2f%% of channel samples differ", ratio * 100)
            : nil
    }
}

/// A factory that paints a translucent fill and a hairline border, so the box
/// structure of a laid-out tree is visible in a snapshot. Registered for
/// `container` / `image` in the snapshot tests; also a minimal example of the
/// `FlexViewFactory` extension point.
public struct DebugBoxFactory: FlexViewFactory {
    let fill: UIColor

    public init(fill: UIColor) { self.fill = fill }

    public func makeView(for tree: LayoutTree) -> UIView {
        let view = UIView()
        view.backgroundColor = fill
        view.layer.borderColor = UIColor.label.withAlphaComponent(0.25).cgColor
        view.layer.borderWidth = 1
        return view
    }
}
#endif
