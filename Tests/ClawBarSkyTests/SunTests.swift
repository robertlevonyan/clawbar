import CoreGraphics
import Foundation
import Testing
import ClawBarShared
import ClawBarSky

/// The sun on Set-OnArc: p = (t − sunrise)/(sunset − sunrise), Left = 7 + p(w − 14) − half,
/// Top = h + 3 − sin(πp)(h − 12) − half. Sunrise 07:00 and sunset 19:00, so p = (t − 420)/720.
@Suite struct SunTests {
    @Test func atNoonTheSunAndItsGlowStandAtTheZenith() throws {
        let sprites = Sprites(firstFrame(inputs(utcDay(780))))
        let sun = try #require(sprites.sun)
        // half 4.9: Left 7 + 111 − 4.9, Top 46 − 31 − 4.9.
        #expect(pixelRows(sun.rects, px: 1.4, origin: CGPoint(x: 113.1, y: 10.1), columns: 7, rows: 7)
            == ["..###..", ".#####.", "#######", "#######", "#######", ".#####.", "..###.."])
        #expect(near(topLeft(sun.rects), CGPoint(x: 113.1, y: 10.1)))
        #expect(sun.color == RGBA("#FFFDE68A") && sun.opacity == 1)
        let glow = try #require(sprites.glow)
        #expect(near(glow.rect.origin, CGPoint(x: 108, y: 5)) && glow.rect.size == CGSize(width: 20, height: 20))
        #expect(glow.opacity == 1)
    }

    @Test func aLowSunTurnsOrange() throws {
        // p = 0.1: Mix(sunLow, sunHigh, sin(0.1π)·1.6 = 0.494) = #FFFCBC63; Top 41.1 − 0.309·31.
        let sun = try #require(Sprites(firstFrame(inputs(utcDay(492)))).sun)
        #expect(sun.color == RGBA("#FFFCBC63"))
        #expect(near(topLeft(sun.rects), CGPoint(x: 24.3, y: 31.5205), 1e-4))
    }

    @Test(arguments: [(384.0, true), (369.6, false), (1176, true), (1190.4, false), (60, false)])
    func theArcRunsSlightlyPastEitherHorizon(minutes: Double, shown: Bool) {
        // p = −0.05 and 1.05 are drawn (below the edge, sunLow), −0.07 and 1.07 are not, nor is midnight.
        let sprites = Sprites(firstFrame(inputs(utcDay(minutes))))
        #expect((sprites.sun != nil) == shown)
        #expect((sprites.glow != nil) == shown)
        if shown { #expect(sprites.sun?.color == RGBA("#FFFB923C")) }
    }

    @Test(arguments: [(2, 0.425, true), (3, 0.0225, true), (63, 0.0, false), (95, 0.0, false)])
    func cloudCoverFadesTheSunAndHeavyCoverHidesIt(code: Int, opacity: Double, shown: Bool) {
        // vis = max(0, 1 − cover × 1.15).
        let sprites = Sprites(firstFrame(inputs(utcDay(780), weather: SkyWeather(code: code, windKmh: 10))))
        #expect((sprites.sun != nil) == shown)
        #expect((sprites.glow != nil) == shown)
        if let sun = sprites.sun, let glow = sprites.glow {
            #expect(near(sun.opacity, opacity, 1e-12) && near(glow.opacity, opacity, 1e-12))
        }
    }
}
