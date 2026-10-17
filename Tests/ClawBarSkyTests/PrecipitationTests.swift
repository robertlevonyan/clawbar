import CoreGraphics
import Foundation
import Testing
import ClawBarShared
import ClawBarSky

/// Fog, rain, snow and the settled-snow strip. With every draw 0.5: fog bands start at x 0.5; a drop respawns
/// at x = 0.5(w + 10) − 10 = 113, y = h/2, v = 4.25; a flake at x = w/2, y = h/2, v = 0.475, phase 3.14.
@Suite struct PrecipitationTests {
    private func run(_ sky: SkyEngine, _ input: SkyInputs, ticks: Int, size: CGSize = skySize) -> Sprites {
        var frame = SkyFrame.empty
        for _ in 0 ..< ticks { frame = sky.step(size: size, inputs: input) }
        return Sprites(frame)
    }

    private func at(_ code: Int, minutes: Double = 780, wind: Double = 12) -> SkyInputs {
        inputs(utcDay(minutes), weather: SkyWeather(code: code, windKmh: wind))
    }

    // MARK: Fog

    @Test func fogDrawsThreeSoftBandsThatCrawlAndBreathe() throws {
        let fog = run(SkyEngine(random: FixedRandom()), at(45), ticks: 1).fog
        try #require(fog.count == 3)
        // Left (0.5015 − 0.6) × 236; Top 0.42, 0.62, 0.82 × 43; opacity 0.14 + 0.05 sin(1/20 + 10 fy).
        #expect(fog.allSatisfy { near($0.rect.minX, -23.246, 1e-9) && $0.rect.width == 141.6 && $0.rect.height == 3 })
        #expect(zip(fog.map(\.rect.minY), [18.06, 26.66, 35.26]).allSatisfy { near($0, $1, 1e-9) })
        #expect(zip(fog.map(\.opacity), [0.095_251, 0.138_341, 0.186_130]).allSatisfy { near($0, $1, 1e-6) })
    }

    @Test func fogWrapsAfterOnePointSix() throws {
        let sky = SkyEngine(random: FixedRandom())
        #expect(near(try #require(run(sky, at(48), ticks: 733).fog.first).rect.minX, 235.882, 1e-6))
        #expect(near(try #require(run(sky, at(48), ticks: 1).fog.first).rect.minX, -141.364, 1e-6))
    }

    @Test func fogBandsUseTheirGradient() throws {
        let frame = SkyEngine(random: FixedRandom()).step(size: skySize, inputs: at(45))
        let stops = frame.ops.compactMap { op -> [GradientStop]? in
            if case .hGradient(_, let stops, _) = op { return stops }
            return nil
        }
        #expect(stops.count == 3)
        #expect(stops.first == [
            GradientStop(location: 0, color: RGBA("#00E5E7EB")),
            GradientStop(location: 0.5, color: RGBA("#FFE5E7EB")),
            GradientStop(location: 1, color: RGBA("#00E5E7EB")),
        ])
    }

    @Test(arguments: [0, 3, 63, 73])
    func onlyFogKindsHaveFog(code: Int) {
        #expect(run(SkyEngine(random: FixedRandom()), at(code), ticks: 1).fog.isEmpty)
    }

    // MARK: Rain

    @Test(arguments: [(53, 10), (63, 20), (61, 12), (65, 27), (82, 37), (95, 17), (0, 0), (73, 0)])
    func dropsFollowTheKindAtTheSkysWidth(code: Int, drops: Int) {
        // round(rain × 236/140): 6 → 10.1, 12 → 20.2, 7 → 11.8, 16 → 27.0, 22 → 37.1, 10 → 16.9.
        #expect((run(SkyEngine(random: FixedRandom()), at(code), ticks: 1).drops?.rects.count ?? 0) == drops)
    }

    @Test func aWideSkyStopsAtFortyDrops() {
        #expect(run(SkyEngine(random: FixedRandom()), at(82), ticks: 1, size: CGSize(width: 400, height: 43)).drops?.rects.count == 40)
    }

    @Test func dropsFallAndSlantWithTheWind() throws {
        // Wind 12: slant 0.48 a tick. The first spawn spreads drops through the sky (y = h/2).
        let sky = SkyEngine(random: FixedRandom())
        let first = try #require(run(sky, at(63), ticks: 1).drops)
        #expect(first.color == RGBA("#8093C5FD") && first.opacity == 1)
        #expect(first.rects.allSatisfy { near($0.origin, CGPoint(x: 113.48, y: 25.75)) && $0.size == CGSize(width: 1, height: 3.5) })
        let sixth = try #require(run(sky, at(63), ticks: 5).drops)
        #expect(sixth.rects.allSatisfy { near($0.origin, CGPoint(x: 115.88, y: 47), 1e-9) })
        // Below the bottom a drop starts again just above the top.
        let seventh = try #require(run(sky, at(63), ticks: 1).drops)
        #expect(seventh.rects.allSatisfy { near($0.origin, CGPoint(x: 113.48, y: 0.25)) })
    }

    @Test func theSlantStopsAtOnePointTwo() throws {
        let drops = try #require(run(SkyEngine(random: FixedRandom()), at(63, wind: 50), ticks: 1).drops)
        #expect(drops.rects.allSatisfy { near($0.minX, 113 + 1.2) })
    }

    @Test func dropsThatStopRainingRespawnThroughTheSky() throws {
        let sky = SkyEngine(random: FixedRandom())
        _ = run(sky, at(63), ticks: 3)
        #expect(run(sky, at(0), ticks: 1).drops == nil)
        // Reset to y = −99 while hidden, so they come back spread out, not from the top.
        let back = try #require(run(sky, at(63), ticks: 1).drops)
        #expect(back.rects.allSatisfy { near($0.minY, 25.75) })
    }

    // MARK: Snow

    @Test(arguments: [(71, 10), (73, 17), (75, 24), (77, 13), (85, 24), (86, 24), (63, 0)])
    func flakesFollowTheKindAtTheSkysWidth(code: Int, flakes: Int) {
        #expect((run(SkyEngine(random: FixedRandom()), at(code), ticks: 1).flakes?.rects.count ?? 0) == flakes)
    }

    @Test func aWideSkyStopsAtThirtyFourFlakes() {
        // round(14 × 400/140) = 40.
        #expect(run(SkyEngine(random: FixedRandom()), at(75), ticks: 1, size: CGSize(width: 400, height: 43)).flakes?.rects.count == 34)
    }

    @Test func flakesSwayAndDriftWithTheWind() throws {
        // Left = x + 1.5 sin(tick/9 + ph) + slant·y/4, Top = y.
        let sky = SkyEngine(random: FixedRandom())
        let first = try #require(run(sky, at(73), ticks: 1).flakes)
        #expect(first.color == RGBA("#C0E4E4E7") && first.opacity == 1)
        #expect(first.rects.allSatisfy { near($0.origin, CGPoint(x: 120.473_051, y: 21.975), 1e-6) && $0.size == CGSize(width: 1.6, height: 1.6) })
        let second = try #require(run(sky, at(73), ticks: 1).flakes)
        #expect(second.rects.allSatisfy { near($0.origin, CGPoint(x: 120.365_734, y: 22.45), 1e-6) })
    }

    @Test func flakesBelowTheBottomStartAgainAtTheTop() throws {
        // y climbs 0.475 a tick from 21.5: past 43 after 46 ticks, then respawns at −2 + 0.475.
        let sky = SkyEngine(random: FixedRandom())
        _ = run(sky, at(73), ticks: 46)
        let again = try #require(run(sky, at(73), ticks: 1).flakes)
        #expect(again.rects.allSatisfy { near($0.minY, -2 + 0.475) })
    }

    // MARK: Settled snow

    @Test(arguments: [(780.0, 73, "#80DDE4EC"), (60, 71, "#50A1A8B5"), (1150, 85, "#68BFC6D0"), (780, 77, "#80DDE4EC")])
    func snowLeavesAStripOnTheGroundLitByTheSky(minutes: Double, code: Int, color: String) throws {
        let ground = try #require(run(SkyEngine(random: FixedRandom()), at(code, minutes: minutes), ticks: 1).ground)
        #expect(ground.rects == [CGRect(x: 0, y: 41.5, width: 236, height: 1.5)])
        #expect(ground.color == RGBA(color) && ground.opacity == 1)
    }

    @Test(arguments: [0, 63, 45])
    func noStripWithoutSnow(code: Int) {
        #expect(run(SkyEngine(random: FixedRandom()), at(code), ticks: 1).ground == nil)
    }
}
