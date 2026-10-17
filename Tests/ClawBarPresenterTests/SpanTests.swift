import Foundation
import Testing
import ClawBarPresenter
import ClawBarShared

// Expected values follow format.ps1 Format-Span: TimeSpan components, Floor(TotalHours), {1:00} minutes.
@Suite struct SpanTests {
    private func span(_ seconds: TimeInterval, _ lang: Lang = .en) -> String? {
        Span.text(until: Samples.now.addingTimeInterval(seconds), now: Samples.now, lang: lang)
    }

    @Test(arguments: [0.0, -0.5, -60, -86_400])
    func nothingAtOrBelowZero(seconds: Double) {
        #expect(span(seconds) == nil)
    }

    @Test func underAnHourShowsWholeMinutes() {
        #expect(span(0.5) == "0m")
        #expect(span(59.9) == "0m")
        #expect(span(60) == "1m")
        #expect(span(35 * 60 + 59) == "35m")
        #expect(span(3599.9) == "59m")
    }

    @Test func fromAnHourTheHoursAreFlooredAndTheMinutesPadded() {
        #expect(span(3600) == "1h 00m")
        #expect(span(2 * 3600 + 5 * 60) == "2h 05m")
        #expect(span(4 * 3600 + 59 * 60 + 59) == "4h 59m")
        #expect(span(24 * 3600 - 0.1) == "23h 59m")
    }

    @Test func fromADayTheDaysAndTheHourComponent() {
        #expect(span(24 * 3600) == "1d 0h")
        #expect(span(25 * 3600 + 59 * 60) == "1d 1h")
        #expect(span(402_900) == "4d 15h")
        #expect(span(6 * 86_400 + 23 * 3600 + 59 * 60) == "6d 23h")
    }

    @Test func germanUsesTheMacUnitSymbols() {
        #expect(span(35 * 60, .de) == "35min")
        #expect(span(2 * 3600 + 5 * 60, .de) == "2h 05min")
        #expect(span(402_900, .de) == "4d 15h")
    }
}
