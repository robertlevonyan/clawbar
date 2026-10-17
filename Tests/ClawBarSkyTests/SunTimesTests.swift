import Foundation
import Testing
import ClawBarShared
import ClawBarSky

/// weather.ps1 Get-SunTimes, read in the location's zone, with sunrise always before sunset.
/// NOAA expectations come from an independent transcription of Get-SunCalc; almanac times are noted where known.
@Suite struct SunTimesTests {
    let berlinPlace = Place(lat: 52.52, lon: 13.405, city: "Berlin", timeZoneID: "Europe/Berlin")
    /// Configured coordinates: no city, no zone.
    let tokyoConfigured = Place(lat: 35.6762, lon: 139.6503)
    let tromso = Place(lat: 69.6492, lon: 18.9553, city: "Tromsø", timeZoneID: "Europe/Oslo")
    let reykjavik = Place(lat: 64.1466, lon: -21.9426, city: "Reykjavík", timeZoneID: "Atlantic/Reykjavik")

    private func openMeteo(_ sr: Double?, _ ss: Double?, zone: String?, at: Date) -> WeatherSnapshot {
        WeatherSnapshot(code: 2, tempC: 10, windKmh: 10, sunriseMin: sr, sunsetMin: ss, timeZoneID: zone, at: at)
    }

    @Test func openMeteosMinutesWinWithoutAFreshnessCheck() {
        let now = Samples.now
        let stale = openMeteo(441, 1079, zone: "Europe/Berlin", at: now.addingTimeInterval(-10 * 3600))
        let (sun, zone) = SkyInfo.sunTimes(stale, place: berlinPlace, now: now, localZone: Zones.tokyo)
        #expect(sun == SunTimes(sunrise: 441, sunset: 1079))
        #expect(zone.identifier == "Europe/Berlin")
    }

    @Test func withoutOpenMeteoTimesNOAARunsForThePlaceInItsZone() {
        // met.no has no sun times. Almanac for Berlin on 2026-10-17: 07:34 and 18:09 CEST.
        let metNo = openMeteo(nil, nil, zone: nil, at: Samples.now)
        let (sun, zone) = SkyInfo.sunTimes(metNo, place: berlinPlace, now: Samples.now, localZone: Zones.tokyo)
        #expect(zone.identifier == "Europe/Berlin")
        #expect(near(sun.sunrise, 454.273, 0.01))
        #expect(near(sun.sunset, 1088.657, 0.01))
        // Only one of the two Open-Meteo times is as good as none.
        let half = openMeteo(441, nil, zone: "Europe/Berlin", at: Samples.now)
        #expect(near(SkyInfo.sunTimes(half, place: berlinPlace, now: Samples.now, localZone: Zones.tokyo).0.sunrise, 454.273, 0.01))
    }

    @Test func withNothingKnownItIsSevenToNineteenInTheMacsZone() {
        let (sun, zone) = SkyInfo.sunTimes(nil, place: nil, now: Samples.now, localZone: Zones.tokyo)
        #expect(sun == SunTimes(sunrise: 420, sunset: 1140))
        #expect(zone == Zones.tokyo)
    }

    @Test func theZoneIsOpenMeteosThenTheIPLookupsThenTheMacs() {
        let now = Samples.now
        let ipPlace = Place(lat: 52.52, lon: 13.405, city: "Berlin", timeZoneID: "Europe/Berlin")
        #expect(SkyInfo.sunTimes(openMeteo(441, 1079, zone: "Asia/Tokyo", at: now), place: ipPlace, now: now, localZone: Zones.utc).1 == Zones.tokyo)
        #expect(SkyInfo.sunTimes(openMeteo(441, 1079, zone: nil, at: now), place: ipPlace, now: now, localZone: Zones.utc).1 == Zones.berlin)
        #expect(SkyInfo.sunTimes(openMeteo(441, 1079, zone: "Not/AZone", at: now), place: ipPlace, now: now, localZone: Zones.utc).1 == Zones.berlin)
        #expect(SkyInfo.sunTimes(nil, place: Place(lat: 52.52, lon: 13.405), now: now, localZone: Zones.utc).1 == Zones.utc)
    }

    @Test func dstMovesNOAAsClockOnTheDayItself() {
        // Almanac: 05:51 CET on the 28th, 06:46 CEST on the 30th.
        let before = SkyInfo.sunTimes(nil, place: berlinPlace, now: local(2026, 3, 28, 12, 0, in: Zones.berlin), localZone: Zones.utc).0
        let after = SkyInfo.sunTimes(nil, place: berlinPlace, now: local(2026, 3, 30, 12, 0, in: Zones.berlin), localZone: Zones.utc).0
        #expect(near(before.sunrise, 351.313, 0.01))
        #expect(near(after.sunrise, 406.576, 0.01))
    }

    @Test func configuredCoordinatesAreReadInTheLocationsZoneFromOpenMeteo() {
        // Tokyo coordinates on a Mac in Berlin: Open-Meteo's timezone puts NOAA (no times parsed) in Tokyo's clock.
        let now = local(2026, 10, 17, 12, 0, in: Zones.tokyo)
        let weather = openMeteo(nil, nil, zone: "Asia/Tokyo", at: now)
        let (sun, zone) = SkyInfo.sunTimes(weather, place: tokyoConfigured, now: now, localZone: Zones.berlin)
        #expect(zone == Zones.tokyo)
        #expect(near(sun.sunrise, 348.847, 0.01))
        #expect(near(sun.sunset, 1024.121, 0.01))
        #expect(sun.sunrise < sun.sunset)
    }

    @Test func farCoordinatesInTheMacsZoneCrossMidnightAndTheSunsetMovesToTomorrow() {
        // No zone known: Tokyo's sun in Berlin's clock rises at 22:48 and sets at 10:04 the next morning.
        let now = local(2026, 10, 17, 12, 0, in: Zones.berlin)
        let (sun, zone) = SkyInfo.sunTimes(nil, place: tokyoConfigured, now: now, localZone: Zones.berlin)
        #expect(zone == Zones.berlin)
        #expect(near(sun.sunrise, 1368.847, 0.01))
        #expect(near(sun.sunset, 604.121 + 1440, 0.01))
    }

    @Test func reykjavikAtTheSolsticeSetsAfterMidnight() {
        // Almanac: 02:55 and 00:04 the next day. NOAA wraps the sunset to 4 min; the guard keeps it tomorrow.
        let now = local(2026, 6, 21, 12, 0, in: Zones.reykjavik)
        let noaa = SkyInfo.sunTimes(nil, place: reykjavik, now: now, localZone: Zones.berlin).0
        #expect(near(noaa.sunrise, 174.391, 0.01))
        #expect(near(noaa.sunset, 1444.025, 0.01))
        // Open-Meteo's next-day sunset reads as 00:04 too.
        let om = SkyInfo.sunTimes(openMeteo(175, 4, zone: "Atlantic/Reykjavik", at: now), place: reykjavik, now: now, localZone: Zones.berlin).0
        #expect(om == SunTimes(sunrise: 175, sunset: 1444))
    }

    @Test(arguments: [false, true])
    func polarDayKeepsTheSunUpAllDay(fromOpenMeteo: Bool) {
        // NOAA clamps to sunrise 00:56 and sunset 00:35; Open-Meteo reports 00:00 and the next midnight (00:00).
        let now = local(2026, 6, 21, 0, 30, in: Zones.oslo)
        let weather = fromOpenMeteo ? openMeteo(0, 0, zone: "Europe/Oslo", at: now) : nil
        let (sun, zone) = SkyInfo.sunTimes(weather, place: tromso, now: now, localZone: Zones.berlin)
        #expect(zone == Zones.oslo)
        #expect(sun.sunrise < sun.sunset)
        #expect(sun.sunrise <= 0 && sun.sunset >= 1440, "the sun is up from before midnight to after the next: \(sun)")
    }

    @Test(arguments: [false, true])
    func polarNightKeepsTheSunDownAllDay(fromOpenMeteo: Bool) {
        // NOAA clamps to a 20.5-minute day around noon; Open-Meteo reports sunrise = sunset = 00:00.
        let now = local(2026, 12, 21, 12, 0, in: Zones.oslo)
        let weather = fromOpenMeteo ? openMeteo(0, 0, zone: "Europe/Oslo", at: now) : nil
        let sun = SkyInfo.sunTimes(weather, place: tromso, now: now, localZone: Zones.berlin).0
        #expect(sun.sunrise < sun.sunset)
        #expect(sun.sunset <= 0 || sun.sunrise >= 1440, "no part of today is between sunrise and sunset: \(sun)")
    }

    @Test func openMeteosPolarTimesWithoutAPlaceFallBack() {
        let weather = openMeteo(0, 0, zone: "Europe/Oslo", at: Samples.now)
        #expect(SkyInfo.sunTimes(weather, place: nil, now: Samples.now, localZone: Zones.berlin).0 == .fallback)
    }
}
