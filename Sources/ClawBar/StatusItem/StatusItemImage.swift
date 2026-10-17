import AppKit
import CoreText
import ClawBarShared

/// The menu bar picture: a mini Clawd next to a pill with the session %. Rects are in points, y down.
enum StatusItemImage {
    static let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)

    /// One point per pixel of `PixelArt.clawdStanding`, one point low so the visible ten rows are centred.
    static let clawdRect = CGRect(x: 0, y: 4, width: 18, height: 12)

    /// Wide enough for "100", so the item never shifts when the number gains a digit.
    static let pillRect: CGRect = {
        let width = (textWidth("100") + 10).rounded(.up)
        return CGRect(x: clawdRect.maxX + 4, y: 2, width: width, height: 14)
    }()

    static let size = CGSize(width: pillRect.maxX, height: 18)

    static func textWidth(_ text: String) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line(text), nil, nil, nil))
    }

    static func make(text: String, color: RGBA) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(text: text, color: color, in: ctx)
            return true
        }
        // Coloured on purpose: the pill carries its own background on light and dark bars.
        image.isTemplate = false
        return image
    }

    private static func draw(text: String, color: RGBA, in ctx: CGContext) {
        for (value, ink) in [(Character("#"), Palette.clawdBody), (Character("o"), Palette.clawdEyes)] {
            ctx.setFillColor(cgColor(ink))
            for r in PixelArt.rects(PixelArt.clawdStanding, value: value, px: 1, py: 1, origin: clawdRect.origin) {
                ctx.fill(flipped(r))
            }
        }
        let pill = flipped(pillRect)
        ctx.setFillColor(cgColor(color))
        ctx.addPath(CGPath(roundedRect: pill, cornerWidth: pill.height / 2, cornerHeight: pill.height / 2, transform: nil))
        ctx.fillPath()

        let l = line(text)
        let width = CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil))
        // Digits are cap height tall: centring the cap height centres the number.
        ctx.textPosition = CGPoint(x: pill.midX - width / 2, y: pill.midY - font.capHeight / 2)
        CTLineDraw(l, ctx)
    }

    private static func line(_ text: String) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    private static func flipped(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: size.height - r.maxY, width: r.width, height: r.height)
    }
}

func cgColor(_ c: RGBA) -> CGColor {
    CGColor(srgbRed: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255, alpha: c.alpha)
}

/// Hands out the same image until the text or the colour changes.
final class StatusItemImageCache {
    private(set) var builds = 0
    private var key: (text: String, color: RGBA)?
    private var current: NSImage?

    func image(text: String, color: RGBA) -> NSImage {
        if let current, let key, key.text == text, key.color == color { return current }
        let image = StatusItemImage.make(text: text, color: color)
        builds += 1
        key = (text, color)
        current = image
        return image
    }
}
