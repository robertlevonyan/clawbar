import CoreGraphics
import Foundation
import Testing
import ClawBarShared
import ClawBarSky

/// Stars: 20 at Left = round(fx(w − 2)), Top = round(2 + fy·h) with fy = rand × 0.6, opacity
/// starOp × (0.55 + 0.45 sin(tick/7 + 1.7i)), starOp = (1 − 2·light) × max(0, 1 − 1.4·cover).
@Suite struct StarTests {
    /// Star 0 gets fx 0.25 and fy 0.3, star 1 fx 0.75 and fy 0.06, the rest fx 0.5 and fy 0.3.
    private func engine() -> SkyEngine { SkyEngine(random: ScriptedRandom([0.25, 0.5, 0.75, 0.1])) }

    @Test func starsAreLaidOutFromTheirFractionsRoundedHalfToEven() throws {
        let stars = Sprites(engine().step(size: skySize, inputs: inputs(utcDay(60)))).stars
        try #require(stars.count == 20)
        // 0.25 × 234 = 58.5 → 58; 0.75 × 234 = 175.5 → 176; 2 + 0.3 × 43 = 14.9 → 15; 2 + 0.06 × 43 = 4.58 → 5.
        #expect(stars[0].rects == [CGRect(x: 58, y: 15, width: 1.2, height: 1.2)])
        #expect(stars[1].rects == [CGRect(x: 176, y: 5, width: 1.2, height: 1.2)])
        #expect(stars[2].rects == [CGRect(x: 117, y: 15, width: 1.2, height: 1.2)])
        #expect(stars.allSatisfy { $0.color == RGBA("#FFF8FAFC") })
    }

    @Test func aNewSizeLaysThemOutAgain() throws {
        let sky = engine()
        _ = sky.step(size: skySize, inputs: inputs(utcDay(60)))
        let stars = Sprites(sky.step(size: CGSize(width: 140, height: 40), inputs: inputs(utcDay(60)))).stars
        try #require(stars.count == 20)
        // 0.25 × 138 = 34.5 → 34; 2 + 0.3 × 40 = 14.
        #expect(stars[0].rects == [CGRect(x: 34, y: 14, width: 1.2, height: 1.2)])
    }

    @Test func theyTwinkleTickByTick() throws {
        let sky = engine()
        let first = Sprites(sky.step(size: skySize, inputs: inputs(utcDay(60)))).stars
        let second = Sprites(sky.step(size: skySize, inputs: inputs(utcDay(60)))).stars
        try #require(first.count == 20 && second.count == 20)
        // Clear night: starOp 1. 0.55 + 0.45 sin(1/7) = 0.614067, sin(1/7 + 1.7) → 0.983449, sin(2/7) → 0.676829.
        #expect(near(first[0].opacity, 0.614_067, 1e-6))
        #expect(near(first[1].opacity, 0.983_449, 1e-6))
        #expect(near(second[0].opacity, 0.676_829, 1e-6))
    }

    @Test(arguments: [
        (60.0, 0, 1.0),  // clear night
        (375, 0, 0.5),  // halfway to dawn: light 0.25
        (60, 2, 0.3),  // partly cloudy night: 1 − 0.7
        (60, 45, 0.02),  // fog: 1 − 0.98
    ])
    func starOpacityFallsWithLightAndCover(minutes: Double, code: Int, starOp: Double) throws {
        let stars = Sprites(engine().step(size: skySize, inputs: inputs(utcDay(minutes), weather: SkyWeather(code: code, windKmh: 8)))).stars
        try #require(stars.count == 20)
        #expect(near(stars[0].opacity, starOp * 0.614_067, 1e-6))
    }

    @Test(arguments: [(410.0, 0), (780, 0), (60, 51), (60, 3)])
    func noStarsFromDawnOnOrUnderThickCloud(minutes: Double, code: Int) {
        // Dawn's light 0.5 or more, or cover ≥ 1/1.4.
        let frame = engine().step(size: skySize, inputs: inputs(utcDay(minutes), weather: SkyWeather(code: code, windKmh: 8)))
        #expect(Sprites(frame).stars.isEmpty)
    }
}
