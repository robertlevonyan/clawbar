import Foundation
import Testing
@testable import ClawBarClawd
import ClawBarShared

/// Step-MascotDemo: 27 entries in turn, each with its own length, and the caption that names them.
@Suite struct DemoTests {
    /// visuals-verbatim.txt §E: moods and crit 55 ticks, the drain 177, an act its length + 12.
    static let entries: [(tag: String, length: Int)] = [
        ("burrows in", 55), ("climbs out of the burrow", 55), ("wandering", 55), ("working", 55),
        ("sweating near the limit", 55), ("waiting for you", 55), ("full of energy", 177),
        ("jump", 24), ("looks around", 23), ("celebrate", 27), ("skip", 26), ("spin", 22), ("peekaboo", 33),
        ("drops in", 25), ("waddle", 31), ("peek", 32), ("wink", 18), ("boop", 23), ("tap dance", 26),
        ("sneeze", 24), ("turn around", 31), ("coin hop", 26), ("wave", 36), ("stretch", 34), ("yawn", 34),
        ("stumble", 32), ("soul leaves", 78),
    ]

    @Test func theDemoRunsTwentySevenEntriesInTurn() {
        #expect(Self.entries.count == 27)
        let total = Self.entries.map(\.length).reduce(0, +)
        #expect(total == 1112)

        let engine = ClawdEngine.settled()
        engine.perform(.demo)
        #expect(engine.devState == ClawdDevState(demoRunning: true))
        let captions = engine.run(total).map(\.devCaption)

        var start = 0
        for (k, entry) in Self.entries.enumerated() {
            // The first tick of each entry shows its number and what it shows.
            #expect(captions[start] == "demo \(k + 1)/27 · \(entry.tag)", "entry \(k + 1)")
            for s in start ..< start + entry.length - 1 {
                #expect(captions[s].hasPrefix("demo \(k + 1)/27 · "), "entry \(k + 1), tick \(s + 1)")
            }
            start += entry.length
            // On an entry's last tick the stepper has already moved on, as in the original.
            if k < 26 { #expect(captions[start - 1].hasPrefix("demo \(k + 2)/27 · "), "end of entry \(k + 1)") }
        }
        // After the last entry: back to live data, no caption.
        #expect(captions[total - 1] == "")
        #expect(engine.devState == ClawdDevState())
    }

    @Test func entriesForceTheirStateAndTheirTiming() {
        let engine = ClawdEngine.settled()
        engine.perform(.demo)
        let frames = engine.run(550)
        // Sleep: burrowed in after 30 ticks, with a 'z'.
        #expect(FrameView(frames[40]).z)
        // Crit work sweats; wait hops with '?'.
        #expect(FrameView(frames[230]).sweat.count == 1)
        #expect(FrameView(frames[280]).bubble == "?")
        // The drain empties the hearts while running: none, then six halves, then belly-up.
        #expect(frames[329].hearts == .hidden && frames[330].hearts.shownHalves == 6)
        expectPose(frames[480], ClawdPose(eyes: .x, flip: true))
        #expect(frames[480].devCaption == "demo 7/27 · limit reached")
        #expect(frames[500].devCaption == "demo 7/27 · working")
        #expect(engine.tickMilliseconds == 90)
    }

    @Test func menuActionsAndTheDemo() {
        // A mood or Auto stops it; an animation plays over it.
        let mood = ClawdEngine.settled()
        mood.perform(.demo)
        mood.run(3)
        mood.perform(.mood(.work))
        #expect(mood.devState == ClawdDevState(forcedMood: .work))
        // The demo's first entry had burrowed him in: he climbs out first.
        #expect(mood.step(env()).devCaption == "dev · climbs out of the burrow")

        let anim = ClawdEngine.settled()
        anim.perform(.demo)
        anim.run(3)
        anim.perform(.act(.wink))
        #expect(anim.devState.demoRunning)
        #expect(anim.step(env()).devCaption == "demo 1/27 · wink")

        let auto = ClawdEngine.settled()
        auto.perform(.demo)
        auto.run(400)
        auto.perform(.auto)
        #expect(auto.devState == ClawdDevState())
        #expect(auto.step(env()).devCaption == "")

        // Choosing hearts stops the demo only while its drain runs.
        let hearts = ClawdEngine.settled()
        hearts.perform(.demo)
        hearts.run(3)
        hearts.perform(.hearts(3))
        #expect(hearts.devState == ClawdDevState(forcedMood: .sleep, forceHearts: 3, demoRunning: true))
        hearts.run(400)
        hearts.perform(.hearts(4))
        #expect(hearts.devState == ClawdDevState(forceHearts: 4))
    }
}
