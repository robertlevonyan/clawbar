import CoreGraphics
import Foundation
import Testing
@testable import ClawBarClawd
import ClawBarShared

/// tools/record-gif.ps1's scenarios on a virtual clock: fake data at scripted times, one frame per tick.
enum Scenario: String, CaseIterable {
    case tour, sleep, limit, reset, hearts, clicks

    enum Event {
        /// Set-Usage: the session %, resetting in so many minutes.
        case usage(Int, resetMinutes: Double = 192)
        case sessions([SessionState])
        case click
        case drain
        /// The last entry's time is the scenario's length.
        case end
    }

    var events: [(Double, Event)] {
        switch self {
        case .tour:
            [(0, .usage(34)), (0, .sessions([.idle, .idle])), (2.5, .sessions([.busy, .idle])), (4, .usage(36)), (5.5, .usage(39)),
             (7, .usage(42)), (8.5, .sessions([.idle, .idle])), (10.5, .sessions([.idle, .waiting])), (14.5, .end)]
        case .sleep:
            [(0, .usage(12)), (0, .sessions([.idle])), (1.5, .sessions([])), (9, .end)]
        case .limit:
            [(0, .usage(100)), (0, .sessions([.idle])), (2, .click), (9.5, .end)]
        case .reset:
            [(0, .usage(96, resetMinutes: 3)), (0, .sessions([.busy])), (4, .usage(0, resetMinutes: 300)), (8.5, .end)]
        case .hearts:
            [(0, .usage(10)), (0, .sessions([.busy])), (0, .drain), (15.5, .end)]
        case .clicks:
            [(0, .usage(22)), (0, .sessions([.idle])), (1, .click), (3.5, .click), (6, .click), (8.5, .click), (11, .end)]
        }
    }

    /// As the recorder runs it: each tick Clawd steps first, then the events due by n × 90 ms apply, then the frame is kept.
    func play(seed: UInt64, width: Double = 194) -> [ClawdFrame] {
        let engine = ClawdEngine(random: SeededRandomSource(seed: seed), now: t0)
        var pct: Int?
        var reset: Date?
        var sessions: [SessionState] = []
        var frames: [ClawdFrame] = []
        var i = 0
        var n = 0
        let events = self.events
        while true {
            let now = t0 + Double(n) * 0.09
            let frame = engine.step(ClawdStepEnv(areaWidth: width, areaHeight: 43, mouseOverWindow: false, mouseX: nil, now: now, lang: .en))
            var changed = false
            while i < events.count, events[i].0 <= Double(n) * 0.09 {
                switch events[i].1 {
                case .usage(let p, let minutes):
                    pct = p
                    reset = now + minutes * 60
                case .sessions(let s): sessions = s
                case .click: engine.click(now: now)
                case .drain: engine.perform(.drain)
                case .end: break
                }
                i += 1
                changed = true
            }
            if changed {
                engine.apply(ClawdDataInput(
                    busy: sessions.filter { $0 == .busy }.count, waiting: sessions.filter { $0 == .waiting }.count,
                    sessionCount: sessions.count, pct: pct, sessionReset: reset, critPercent: 85
                ), now: now)
            }
            if i >= events.count { return frames }
            frames.append(frame)
            n += 1
        }
    }
}

@Suite struct DeterminismTests {
    @Test(arguments: Scenario.allCases)
    func theSameSeedAndInputsReplayExactly(_ scenario: Scenario) {
        let a = scenario.play(seed: 2026), b = scenario.play(seed: 2026)
        #expect(a.count > 90)
        #expect(a == b)
    }

    @Test func anotherSeedChangesTheRun() {
        #expect(Scenario.clicks.play(seed: 1) != Scenario.clicks.play(seed: 2))
    }

    @Test func clicksGetHeartsAndActs() {
        let frames = Scenario.clicks.play(seed: 2026).map(FrameView.init)
        #expect(frames.count == 123)
        // A click due at T lands after the step of the first tick at or past T, so its heart shows a tick later.
        for k in [12, 39, 67, 95] {
            #expect(frames[k].love == nil && frames[k + 1].love != nil, "click at frame \(k)")
        }
        // The first step runs before any data, as in the recorder.
        #expect(!frames[0].frame.hearts.visible)
        #expect(frames[1...].allSatisfy { $0.frame.hearts.shownHalves == 5 && $0.frame.devCaption.isEmpty })
    }

    @Test func theLimitLiesBellyUpAndTheClickReleasesTheSoul() {
        let frames = Scenario.limit.play(seed: 2026, width: 179).map(FrameView.init)
        #expect(frames.allSatisfy { $0.love == nil })
        #expect(frames[1...].allSatisfy { $0.frame.hearts.shownHalves == 0 && $0.frame.hearts.tooltip == "out of strength · 0% of the session limit left" })
        #expect(frames[..<24].allSatisfy { $0.soul.isEmpty })
        // The click lands after frame 23: the soul act runs from frame 24, visible for t = 7 … 53.
        #expect(frames[30].soul.isEmpty && frames[31].soul.count == 1 && frames[77].soul.count == 1 && frames[78].soul.isEmpty)
        expectPose(frames[22].frame, ClawdPose(eyes: .x, flip: true))
    }

    @Test func theResetCelebrates() {
        let frames = Scenario.reset.play(seed: 2026).map(FrameView.init)
        #expect(frames[..<46].allSatisfy { $0.bubble != "!" })
        #expect(frames[46].bubble == "!" && frames[46].confetti.count == 12)
        // 96% leaves half a heart; after the reset, all six halves.
        #expect(frames[45].frame.hearts.shownHalves == 1 && frames[60].frame.hearts.shownHalves == 6)
    }

    @Test func noSessionsBurrowsInToSleep() {
        let frames = Scenario.sleep.play(seed: 2026).map(FrameView.init)
        #expect(frames[..<18].allSatisfy { !$0.z })
        #expect(frames.last!.z)
        expectPose(frames.last!.frame, ClawdPose(eyes: .closed, dig: 4))
    }

    @Test func theHeartsDrainAndComeBack() {
        let frames = Scenario.hearts.play(seed: 2026)
        let shown = frames.map(\.hearts.shownHalves)
        #expect(shown[1] == 6 && shown.contains(0))
        #expect(frames[150].devCaption == "dev · limit reached")
        #expect(frames.last!.hearts == HeartsFrame(visible: true, shownHalves: 6, tooltip: "full of energy · 90% of the session limit left"))
        #expect(frames.last!.devCaption.isEmpty)
    }

    @Test func theTourWaitsWithAQuestion() {
        let frames = Scenario.tour.play(seed: 2026).map(FrameView.init)
        #expect(frames[..<118].allSatisfy { $0.bubble != "?" })
        #expect(frames[118...].contains { $0.bubble == "?" })
    }
}
