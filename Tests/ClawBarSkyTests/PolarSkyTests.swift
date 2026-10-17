import CoreGraphics
import Foundation
import Testing
import ClawBarShared
import ClawBarSky

/// The sky as the app draws it: SkyInfo's sun times and zone fed into the engine, at high latitudes and far zones.
@Suite struct PolarSkyTests {
    static let tromso = Place(lat: 69.6492, lon: 18.9553, city: "Tromsø", timeZoneID: "Europe/Oslo")
    static let reykjavik = Place(lat: 64.1466, lon: -21.9426, city: "Reykjavík", timeZoneID: "Atlantic/Reykjavik")
    static let tokyoConfigured = Place(lat: 35.6762, lon: 139.6503)

    private func draw(
        _ now: Date, place: Place, weather: WeatherSnapshot? = nil, code: Int = 0, phase: SkyPhase? = nil,
        localZone: TimeZone = Zones.berlin
    ) -> SkyFrame {
        let (sun, zone) = SkyInfo.sunTimes(weather, place: place, now: now, localZone: localZone)
        let input = SkyInputs(
            now: now, timeZone: zone, sun: sun, weather: SkyWeather(code: code, windKmh: 8),
            latitude: SkyInfo.latitude(place: place), forcedPhase: phase
        )
        return SkyEngine(random: SeededRandomSource(seed: 5)).step(size: skySize, inputs: input)
    }

    /// Open-Meteo reports polar day and night alike: sunrise and sunset both read 00:00.
    private func polarOpenMeteo(at now: Date) -> WeatherSnapshot {
        WeatherSnapshot(code: 0, tempC: 5, windKmh: 8, sunriseMin: 0, sunsetMin: 0, timeZoneID: "Europe/Oslo", at: now)
    }

    @Test(arguments: [false, true])
    func aPolarDayMidnightLooksLikeDay(fromOpenMeteo: Bool) {
        // Unguarded, NOAA's sunrise 00:56 after its sunset 00:35 would draw this midnight as night → dawn,
        // and the following noon as night.
        for (h, m) in [(0, 30), (12, 0), (23, 50)] {
            let now = local(2026, 6, 21, h, m, in: Zones.oslo)
            let frame = draw(now, place: Self.tromso, weather: fromOpenMeteo ? polarOpenMeteo(at: now) : nil)
            #expect(frame.top == RGBA("#004A8CCB") && frame.bottom == RGBA("#2E6FA8D8"), "\(h):\(m)")
            let sprites = Sprites(frame)
            #expect(sprites.sun != nil && sprites.glow != nil, "the sun is up at \(h):\(m)")
            #expect(sprites.stars.isEmpty && sprites.moonDark == nil && sprites.moonLit == nil)
        }
    }

    @Test func thePolarDaySunIsLowAtMidnightAndHighAtNoon() throws {
        let midnight = try #require(Sprites(draw(local(2026, 6, 21, 0, 0, in: Zones.oslo), place: Self.tromso)).sun)
        let noon = try #require(Sprites(draw(local(2026, 6, 21, 12, 0, in: Zones.oslo), place: Self.tromso)).sun)
        // Still above the bottom edge at midnight, near the zenith (top 10.1) at noon.
        #expect(topLeft(midnight.rects).y < 43 - 4 && topLeft(midnight.rects).y > 30)
        #expect(near(topLeft(noon.rects).y, 10.1, 0.5))
    }

    @Test(arguments: [false, true])
    func aPolarNightNoonLooksLikeNight(fromOpenMeteo: Bool) {
        // Unguarded, NOAA's 20-minute day at 11:32 would put the sun at the zenith in a dawn sky.
        for (h, m) in [(11, 42), (12, 0), (0, 0)] {
            let now = local(2026, 12, 21, h, m, in: Zones.oslo)
            let frame = draw(now, place: Self.tromso, weather: fromOpenMeteo ? polarOpenMeteo(at: now) : nil)
            #expect(frame.top == RGBA("#00304A8C") && frame.bottom == RGBA("#1A304A8C"), "\(h):\(m)")
            let sprites = Sprites(frame)
            #expect(sprites.sun == nil && sprites.glow == nil)
            #expect(sprites.stars.count == 20)
            #expect(sprites.moonDark != nil || sprites.moonLit != nil, "the moon is out at \(h):\(m)")
        }
    }

    @Test(arguments: [(SkyPhase.dawn, "#00404E8A"), (.day, "#004A8CCB"), (.dusk, "#00383070"), (.night, "#00304A8C")])
    func developerPhasesStillWorkAtThePoles(phase: SkyPhase, top: String) {
        // Polar sun times have no dawn or dusk to pin, so a forced phase uses 07:00 and 19:00.
        #expect(draw(local(2026, 6, 21, 12, 0, in: Zones.oslo), place: Self.tromso, phase: phase).top == RGBA(top))
        #expect(draw(local(2026, 12, 21, 12, 0, in: Zones.oslo), place: Self.tromso, phase: phase).top == RGBA(top))
    }

    @Test func reykjavikJustAfterMidnightIsStillYesterdaysSunset() throws {
        // Sunset 00:04 on the 22nd: at 00:02 the sky is mostly dusk and the sun sits on the horizon
        // (p = 0.998, so its top is 41.1 − sin(0.998π) × 31 = 40.93).
        let frame = draw(local(2026, 6, 22, 0, 2, in: Zones.reykjavik), place: Self.reykjavik)
        #expect(frame.top != RGBA("#00304A8C"))
        let sun = try #require(Sprites(frame).sun)
        #expect(near(topLeft(sun.rects).y, 40.928, 0.01))
        // The short night follows: at 01:30 the moon is up and the sky is night.
        let late = draw(local(2026, 6, 22, 1, 30, in: Zones.reykjavik), place: Self.reykjavik)
        #expect(late.top == RGBA("#00304A8C"))
        #expect(Sprites(late).moonDark != nil || Sprites(late).moonLit != nil)
        // And noon is day, which the crossed times would have drawn as night.
        #expect(draw(local(2026, 6, 22, 12, 0, in: Zones.reykjavik), place: Self.reykjavik).top == RGBA("#004A8CCB"))
    }

    @Test func farCoordinatesInTheMacsZoneStillFollowTheirOwnSun() {
        // No zone known: Tokyo's sun on Berlin's clock. 02:00 CEST is 09:00 in Tokyo, 12:00 CEST is 19:00.
        let morning = draw(local(2026, 10, 17, 2, 0, in: Zones.berlin), place: Self.tokyoConfigured)
        let evening = draw(local(2026, 10, 17, 12, 0, in: Zones.berlin), place: Self.tokyoConfigured)
        #expect(morning.top == RGBA("#004A8CCB"))
        #expect(evening.top == RGBA("#00304A8C"))
        // With Open-Meteo's zone the same moments read the same way on Tokyo's clock.
        let tokyo = WeatherSnapshot(code: 0, tempC: 18, windKmh: 8, timeZoneID: "Asia/Tokyo", at: Samples.now)
        #expect(draw(local(2026, 10, 17, 2, 0, in: Zones.berlin), place: Self.tokyoConfigured, weather: tokyo).top == RGBA("#004A8CCB"))
        #expect(draw(local(2026, 10, 17, 12, 0, in: Zones.berlin), place: Self.tokyoConfigured, weather: tokyo).top == RGBA("#00304A8C"))
    }
}
