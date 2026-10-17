import CoreGraphics
import Foundation
import Testing
import ClawBarShared
import ClawBarSky

/// Clouds: min(9, round(cover × 5 × dens)) with dens = max(1, w/140), fading 0.03 a tick at opacity 0.65 × fade,
/// drifting right by (0.04 + wind/350) × v. With every draw 0.5 a cloud starts at x = w/2 with fy 0.2 and v 1.
@Suite struct CloudTests {
    private func run(_ sky: SkyEngine, _ input: SkyInputs, ticks: Int, size: CGSize = skySize) -> Sprites {
        var frame = SkyFrame.empty
        for _ in 0 ..< ticks { frame = sky.step(size: size, inputs: input) }
        return Sprites(frame)
    }

    private func noon(_ code: Int, wind: Double = 8) -> SkyInputs {
        inputs(utcDay(780), weather: SkyWeather(code: code, windKmh: wind))
    }

    @Test(arguments: [(0, 0), (1, 2), (2, 4), (3, 7), (45, 6), (53, 7), (63, 8), (95, 8), (73, 7)])
    func theCountFollowsCoverAtTheSkysWidth(code: Int, clouds: Int) {
        // dens = 236/140: cover 0.2 → 1.69 → 2, 0.5 → 4.21 → 4, 0.85 → 7.16 → 7, 0.9 → 7.59 → 8, 1.0 → 8.43 → 8.
        #expect(run(SkyEngine(random: FixedRandom()), noon(code), ticks: 1).clouds.count == clouds)
    }

    @Test func narrowSkiesKeepTheBaseCountAndWideOnesStopAtNine() {
        // dens 1: cover 0.9 × 5 = 4.5 → 4 and 0.5 × 5 = 2.5 → 2, half to even. dens 400/140: 14.3 → 9.
        let narrow = CGSize(width: 100, height: 43)
        #expect(run(SkyEngine(random: FixedRandom()), noon(63), ticks: 1, size: narrow).clouds.count == 4)
        #expect(run(SkyEngine(random: FixedRandom()), noon(2), ticks: 1, size: narrow).clouds.count == 2)
        #expect(run(SkyEngine(random: FixedRandom()), noon(95), ticks: 1, size: CGSize(width: 400, height: 43)).clouds.count == 9)
    }

    @Test func cloudsFadeInAndOutThreeHundredthsATick() {
        let sky = SkyEngine(random: FixedRandom())
        #expect(run(sky, noon(2), ticks: 1).clouds.allSatisfy { near($0.opacity, 0.65 * 0.03) })
        #expect(run(sky, noon(2), ticks: 40).clouds.allSatisfy { near($0.opacity, 0.65) })
        let fading = run(sky, noon(0), ticks: 1).clouds
        #expect(fading.count == 4 && fading.allSatisfy { near($0.opacity, 0.65 * 0.97) })
        #expect(run(sky, noon(0), ticks: 40).clouds.isEmpty)
    }

    @Test func theyDriftRightWithTheWindOnWholeUnits() throws {
        // Wind 35: 0.14 a tick, so x = 118 + 1.4 after ten ticks → Left 119; Top = round(0.2 × 43 = 8.6) = 9.
        let sprites = run(SkyEngine(random: FixedRandom()), noon(2, wind: 35), ticks: 10)
        let first = try #require(sprites.clouds.first)
        #expect(pixelRows(first.rects, px: 2, origin: CGPoint(x: 119, y: 9), columns: 12, rows: 4)
            == ["....###.....", "..#######...", ".##########.", "############"])
        #expect(topLeft(first.rects) == CGPoint(x: 119, y: 9))
    }

    @Test func pastTheRightEdgeTheyComeBackFromTheLeft() throws {
        // Wind 350: 1.04 a tick. After 113 ticks x = 235.52; the next tick passes 236 and resets to −width.
        let sky = SkyEngine(random: FixedRandom())
        let before = run(sky, noon(2, wind: 350), ticks: 113).clouds
        #expect(before.map { topLeft($0.rects).x } == [236, 236, 236, 236])
        let after = run(sky, noon(2, wind: 350), ticks: 1).clouds
        // Shapes 0, 1, 2 are 24, 16 and 20 wide; each has a full bottom row, so its left edge is its x.
        #expect(after.map { topLeft($0.rects).x } == [-24, -16, -20, -24])
        #expect(after.allSatisfy { topLeft($0.rects).y == 9 })
    }

    @Test(arguments: [
        (780.0, 2, "#FFB4B4BC"),  // day
        (780, 63, "#FF7E7E87"),  // day with rain: Mix(day, rain grey, 0.55)
        (60, 2, "#FF5E5E68"),  // night
        (60, 63, "#FF575761"),  // night with rain
        (1150, 2, "#FF898992"),  // dusk, light 0.5
        (780, 95, "#FF7E7E87"),  // a storm counts as rain
    ])
    func theirColourFollowsTheLightAndDarkensWithRain(minutes: Double, code: Int, color: String) {
        let sprites = run(SkyEngine(random: FixedRandom()), inputs(utcDay(minutes), weather: SkyWeather(code: code, windKmh: 8)), ticks: 1)
        #expect(!sprites.clouds.isEmpty)
        #expect(sprites.clouds.allSatisfy { $0.color == RGBA(color) })
    }
}
