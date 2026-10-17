import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import ClawBar
import ClawBarShared

@Suite struct IconMakerTests {
    @Test func theIconsetHasEverySizeIconutilNeeds() throws {
        let tmp = TempDir()
        let set = try IconMaker.writeIconset(to: tmp.url)
        #expect(set.lastPathComponent == "AppIcon.iconset")
        let files = try FileManager.default.contentsOfDirectory(atPath: set.path).sorted()
        #expect(files == [
            "icon_128x128.png", "icon_128x128@2x.png", "icon_16x16.png", "icon_16x16@2x.png", "icon_256x256.png",
            "icon_256x256@2x.png", "icon_32x32.png", "icon_32x32@2x.png", "icon_512x512.png", "icon_512x512@2x.png",
        ])
        for name in files {
            let points = Int(name.dropFirst(5).prefix { $0 != "x" })!
            let pixels = name.contains("@2x") ? points * 2 : points
            let src = try #require(CGImageSourceCreateWithURL(set.appendingPathComponent(name) as CFURL, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
            #expect(image.width == pixels && image.height == pixels, "\(name)")
        }
    }

    @Test func clawdStandsInTheMiddleOfADarkRoundedTile() throws {
        let image = try #require(IconMaker.image(pixels: 512))
        let r = Raster(image, scale: 1)
        #expect(r.color(atPoint: 2, 2).a == 0, "the corner outside the tile is transparent")
        #expect(close(r.color(atPoint: 256, IconMaker.clawdRect(pixels: 512).midY), Palette.clawdBody))
        #expect(close(r.color(atPoint: 90, 140), Palette.card))
    }
}
