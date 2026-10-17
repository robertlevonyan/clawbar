import Foundation
import Testing
import ClawBarShared
import ClawBarSky

/// Step-Sky's gradient. Sunrise 07:00 and sunset 19:00 put the palette stops at 05:40 night, 06:50 dawn,
/// 08:10 day, 17:50 day, 19:10 dusk and 20:20 night. Colours are Mix of the palette table (visuals-verbatim H)
/// worked out by hand: per channel a + (b − a)·k, rounded half to even.
@Suite struct PaletteTests {
    @Test(arguments: [
        (300.0, "#00304A8C", "#1A304A8C"),  // before every segment: night
        (340, "#00304A8C", "#1A304A8C"),  // night → dawn, k = 0
        (375, "#00384C8B", "#26886A79"),  // night → dawn, k = 0.5 (bottom alpha 38.5 → 38)
        (410, "#00404E8A", "#33E08A66"),  // dawn → day, k = 0
        (430, "#00425E9A", "#32C49282"),  // dawn → day, k = 0.25 (66.5 → 66, 93.5 → 94, 145.5 → 146)
        (450, "#00456DAA", "#30A8999F"),  // dawn → day, k = 0.5 (170.5 → 170, 167.5 → 168)
        (490, "#004A8CCB", "#2E6FA8D8"),  // day
        (720, "#004A8CCB", "#2E6FA8D8"),  // day → day
        (1070, "#004A8CCB", "#2E6FA8D8"),  // day → dusk, k = 0
        (1110, "#00415E9E", "#30A48994"),  // day → dusk, k = 0.5
        (1150, "#00383070", "#33D86A50"),  // dusk → night, k = 0
        (1185, "#00343D7E", "#26845A6E"),  // dusk → night, k = 0.5
        (1220, "#00304A8C", "#1A304A8C"),  // after every segment: night
    ])
    func aClearSkyFollowsThePaletteSegments(minutes: Double, top: String, bottom: String) {
        let frame = firstFrame(inputs(utcDay(minutes)))
        #expect(frame.top == RGBA(top))
        #expect(frame.bottom == RGBA(bottom))
    }

    @Test func noWeatherIsAClearSky() {
        let frame = firstFrame(inputs(utcDay(375), weather: nil))
        #expect(frame.top == RGBA("#00384C8B") && frame.bottom == RGBA("#26886A79"))
    }

    @Test(arguments: [(3, "#00586470", "#2E707A83"), (63, "#0059626B", "#2E70787F")])
    func cloudCoverDimsTheGradient(code: Int, top: String, bottom: String) {
        // Day at noon dimmed by g = cover × 0.9: overcast 0.765, rain 0.81 (Dim-Color by hand, alpha kept).
        let frame = firstFrame(inputs(utcDay(780), weather: SkyWeather(code: code, windKmh: 10)))
        #expect(frame.top == RGBA(top))
        #expect(frame.bottom == RGBA(bottom))
    }

    @Test func theTimeOfDayIsReadInTheLocationsZone() {
        // 03:00 UTC is noon in Tokyo.
        let now = local(2026, 10, 17, 3, 0, in: Zones.utc)
        #expect(firstFrame(inputs(now, zone: Zones.tokyo)).top == RGBA("#004A8CCB"))
        #expect(firstFrame(inputs(now, zone: Zones.utc)).top == RGBA("#00304A8C"))
    }

    @Test func theWallClockFollowsDST() {
        // 05:15 UTC on the day clocks go forward is 07:15 CEST, not 06:15 CET.
        let now = local(2026, 3, 29, 5, 15, in: Zones.utc)
        #expect(firstFrame(inputs(now, zone: Zones.berlin)) .top == firstFrame(inputs(utcDay(435))).top)
        #expect(firstFrame(inputs(now, zone: Zones.berlin)).top != firstFrame(inputs(utcDay(375))).top)
    }

    @Test(arguments: [
        (SkyPhase.dawn, "#00404E8A", "#33E08A66"),  // sunrise − 10: the dawn stop
        (.day, "#004A8CCB", "#2E6FA8D8"),  // midway between sunrise and sunset
        (.dusk, "#00383070", "#33D86A50"),  // sunset + 10: the dusk stop
        (.night, "#00304A8C", "#1A304A8C"),  // midnight
    ])
    func developerPhasesPinTheTimeOfDay(phase: SkyPhase, top: String, bottom: String) {
        // At 12:00 UTC the clock alone would draw day.
        let frame = firstFrame(inputs(utcDay(720), phase: phase))
        #expect(frame.top == RGBA(top))
        #expect(frame.bottom == RGBA(bottom))
    }
}
