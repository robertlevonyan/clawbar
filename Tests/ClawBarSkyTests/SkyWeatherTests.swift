import Foundation
import Testing
import ClawBarShared
import ClawBarSky

/// weather.ps1 Get-SkyWeather.
@Suite struct SkyWeatherTests {
    let now = Samples.now

    private func live(hoursOld: Double) -> WeatherSnapshot {
        WeatherSnapshot(code: 61, tempC: 4, windKmh: 20, at: now.addingTimeInterval(-hoursOld * 3600))
    }

    @Test func aForcedCodeBlowsAtTwelveKmhWhateverTheLiveWeather() {
        #expect(SkyInfo.skyWeather(live(hoursOld: 0.1), now: now, dev: SkyDevState(weatherCode: 95)) == SkyWeather(code: 95, windKmh: 12))
        #expect(SkyInfo.skyWeather(nil, now: now, dev: SkyDevState(phase: .night, weatherCode: 0)) == SkyWeather(code: 0, windKmh: 12))
    }

    @Test func liveWeatherCountsWhileYoungerThanThreeHours() {
        #expect(SkyInfo.skyWeather(live(hoursOld: 2.99), now: now, dev: SkyDevState()) == SkyWeather(code: 61, windKmh: 20))
        #expect(SkyInfo.skyWeather(live(hoursOld: 3), now: now, dev: SkyDevState()) == nil)
        #expect(SkyInfo.skyWeather(nil, now: now, dev: SkyDevState()) == nil)
    }

    @Test func aForcedPhaseAloneKeepsTheLiveWeather() {
        #expect(SkyInfo.skyWeather(live(hoursOld: 1), now: now, dev: SkyDevState(phase: .dusk)) == SkyWeather(code: 61, windKmh: 20))
    }

    @Test func latitudeIsThePlacesElseFifty() {
        #expect(SkyInfo.latitude(place: Place(lat: -33.87, lon: 151.21)) == -33.87)
        #expect(SkyInfo.latitude(place: nil) == 50)
    }
}

@Suite struct SkyInputsTests {
    @Test func oneTicksInputsComeFromTheDataAndTheOverrides() {
        let d = DataSnapshot.sample
        let inputs = SkyInfo.inputs(d.weather, place: d.place, now: Samples.now, localZone: .gmt, dev: SkyDevState(phase: .night, weatherCode: 95))
        // Open-Meteo's sun times in its own zone, the forced storm with the original's 12 km/h, Berlin's latitude.
        #expect(inputs == SkyInputs(
            now: Samples.now, timeZone: TimeZone(identifier: "Europe/Berlin")!, sun: SunTimes(sunrise: 441, sunset: 1079),
            weather: SkyWeather(code: 95, windKmh: 12), latitude: 52.52, forcedPhase: .night
        ))
    }
}
