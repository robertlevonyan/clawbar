import CoreGraphics
import Foundation
import ClawBarShared

/// `--make-icon <dir>`: AppIcon.iconset drawn from Clawd's pixels, for iconutil.
enum IconMaker {
    /// iconutil's names and pixel sizes.
    static let entries: [(name: String, pixels: Int)] = [16, 32, 128, 256, 512].flatMap { p in
        [("icon_\(p)x\(p)", p), ("icon_\(p)x\(p)@2x", p * 2)]
    }

    static func run(dir: URL) -> Int32 {
        do {
            let set = try writeIconset(to: dir)
            print(set.path)
            return 0
        } catch {
            FileHandle.standardError.write(Data("ClawBar: \(error)\n".utf8))
            return 1
        }
    }

    static func writeIconset(to dir: URL) throws -> URL {
        let set = dir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
        for e in entries {
            guard let image = image(pixels: e.pixels) else { throw CLIError(message: "drawing \(e.name) failed") }
            try Imaging.writePNG(image, to: set.appendingPathComponent("\(e.name).png"))
        }
        return set
    }

    /// The tile on Apple's icon grid: 824 of 1024 with a 185.4 corner radius. Top-left coordinates.
    static func tile(pixels n: Int) -> CGRect {
        let s = Double(n) / 1024
        return CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    }

    /// Clawd's ten visible rows, the widget's 2.0 × 2.2 pixel aspect, snapped to whole pixels where it fits.
    static func clawdRect(pixels n: Int) -> CGRect {
        let t = tile(pixels: n)
        var px = t.width * 0.62 / 18
        if n >= 64 { px = px.rounded(.down) }
        let py = n >= 64 ? (px * 1.1).rounded() : px * 1.1
        var x = (Double(n) - 18 * px) / 2, y = t.minY + t.height * 0.27
        if n >= 64 {
            x = x.rounded()
            y = y.rounded()
        }
        return CGRect(x: x, y: y, width: 18 * px, height: 10 * py)
    }

    static func image(pixels n: Int) -> CGImage? {
        guard let ctx = Imaging.context(width: n, height: n) else { return nil }
        let h = Double(n)
        func flip(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height) }

        let t = tile(pixels: n)
        let radius = 185.4 / 1024 * h
        let tilePath = CGPath(roundedRect: flip(t), cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.addPath(tilePath)
        ctx.setFillColor(cgColor(Palette.card))
        ctx.fillPath()
        // The card's 1-pt rim, scaled.
        let rim = max(1, h / 256)
        ctx.addPath(CGPath(
            roundedRect: flip(t).insetBy(dx: rim / 2, dy: rim / 2), cornerWidth: radius - rim / 2, cornerHeight: radius - rim / 2, transform: nil
        ))
        ctx.setStrokeColor(cgColor(Palette.border))
        ctx.setLineWidth(rim)
        ctx.strokePath()

        let c = clawdRect(pixels: n)
        let px = c.width / 18, py = c.height / 10
        let rows = Array(PixelArt.clawdStanding.prefix(10))
        for (value, ink) in [(Character("#"), Palette.clawdBody), (Character("o"), Palette.clawdEyes)] {
            ctx.setFillColor(cgColor(ink))
            for r in PixelArt.rects(rows, value: value, px: px, py: py, origin: c.origin) { ctx.fill(flip(r)) }
        }

        // The session bar under his feet, a third used.
        let barH = max(1, px * 0.9)
        let bar = CGRect(x: t.minX + t.width * 0.15, y: c.maxY + px * 1.4, width: t.width * 0.7, height: barH)
        for (rect, ink) in [(bar, Palette.track), (CGRect(x: bar.minX, y: bar.minY, width: bar.width * 0.34, height: barH), Palette.ok)] {
            ctx.addPath(CGPath(roundedRect: flip(rect), cornerWidth: barH / 2, cornerHeight: barH / 2, transform: nil))
            ctx.setFillColor(cgColor(ink))
            ctx.fillPath()
        }
        return ctx.makeImage()
    }
}
