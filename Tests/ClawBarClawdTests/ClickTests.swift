import CoreGraphics
import Foundation
import Testing
@testable import ClawBarClawd
import ClawBarShared

/// Start-MascotClick and the entrance act.
@Suite struct ClickTests {
    /// visuals-verbatim.txt §E.
    static let clickActs: [ClawdAct] = [.jump, .look, .spin, .peekaboo, .drop, .wink, .boop, .tap, .sneeze, .turn, .coinHop]
    static let entranceActs: [ClawdAct] = [
        .jump, .look, .skip, .spin, .peekaboo, .drop, .waddle, .peek, .wink, .boop, .tap, .sneeze, .turn, .coinHop,
    ]

    @Test func whenDeadAClickReleasesTheSoulAndNoHeart() {
        let engine = ClawdEngine.settled()
        engine.apply(input(sessions: 1, pct: 100), now: t0)
        _ = engine.step(env())
        engine.click(now: t0)
        let frames = engine.run(66).map(FrameView.init)
        #expect(frames.allSatisfy { $0.love == nil })
        #expect(frames[6].soul.isEmpty && !frames[7].soul.isEmpty && !frames[53].soul.isEmpty && frames[54].soul.isEmpty)
        expectPose(frames[0].frame, ClawdPose(eyes: .x, feet: .right, flip: true))
    }

    @Test func forcedDeadCountsTooAndARunningActBlocksTheSoul() {
        let engine = ClawdEngine.settled()
        engine.perform(.hearts(0))
        _ = engine.step(env())
        engine.click(now: t0)
        #expect(engine.step(env()).devCaption == "dev · soul leaves")

        let busy = ClawdEngine.settled()
        busy.apply(input(sessions: 1, pct: 100), now: t0)
        busy.perform(.act(.wink))
        _ = busy.step(env())
        busy.click(now: t0)
        let frames = busy.run(70).map(FrameView.init)
        #expect(frames.allSatisfy { $0.soul.isEmpty && $0.love == nil })
    }

    @Test func asleepInTheBurrowAClickStirs() {
        let engine = ClawdEngine.settled()
        engine.apply(input(sessions: 0), now: t0)
        engine.run(31)
        engine.click(now: t0)
        let frame = engine.step(env())
        expectPose(frame, ClawdPose(eyes: .wide, dig: 3))
        #expect(FrameView(frame).love != nil)
    }

    @Test func aClickDuringAnActOnlyGetsTheHeart() {
        let engine = ClawdEngine.settled()
        engine.perform(.act(.wave))
        engine.run(2)
        engine.click(now: t0)
        let frame = engine.step(env())
        expectPose(frame, ClawdPose(eyes: .happy, arms: .right))
        #expect(FrameView(frame).love != nil)
        #expect(engine.tickMilliseconds == 90)
    }

    @Test(arguments: 0 ..< 11)
    func otherwiseAUniformlyRandomClickAct(_ k: Int) {
        let random = ScriptedRandom()
        let engine = ClawdEngine.settled(random)
        _ = engine.step(env())
        random.queue(11, k)
        engine.click(now: t0)
        #expect(random.asked.last == 11)

        let reference = ClawdEngine.settled()
        _ = reference.step(env())
        reference.perform(.act(Self.clickActs[k]))
        // Until the act's last frame: from there the heart's happy eyes differ.
        let length = SequenceTests.lengths.first { $0.0 == Self.clickActs[k] }!.1
        for _ in 0 ..< length - 1 {
            let a = engine.step(env()), b = reference.step(env())
            #expect(a.spriteRect == b.spriteRect)
            #expect(FrameView(a).pixels == FrameView(b).pixels)
            #expect(FrameView(a).fx == FrameView(b).fx)
        }
    }

    @Test func theHeartFloatsUpForTwentyTicks() {
        let engine = ClawdEngine.settled()
        _ = engine.step(env())
        engine.click(now: t0)
        let frames = engine.run(21).map(FrameView.init)
        for (n, f) in frames.prefix(20).enumerated() {
            let k = Double(n) / 20
            let heart = f.love
            #expect(heart != nil)
            #expect(abs((heart?.opacity ?? 0) - (1 - k)) < 1e-12)
            // Bottom 23 + 14k above the ground, 13 + 2·sin 6k right of Clawd's x; the heart is 8.4 tall.
            let first = heart?.rects.first ?? .zero
            #expect(abs(first.minX - (72 + 13 + 2 * sin(6 * k) + 1.4)) < 1e-9)
            #expect(abs(first.minY - (-(23 + 14 * k) - 8.4)) < 1e-9)
        }
        #expect(frames[20].love == nil)
    }

    @Test func pettedEyesShowOnceTheActIsOver() {
        let engine = ClawdEngine.settled()
        engine.perform(.act(.wink))
        engine.click(now: t0)
        let frames = engine.run(21)
        expectPose(frames[4], ClawdPose(eyes: .wink))
        // The wink's last frame ends the act, so the heart's happy eyes apply already.
        expectPose(frames[5], ClawdPose(eyes: .happy))
        expectPose(frames[19], ClawdPose(eyes: .happy))
        expectPose(frames[20], ClawdPose())
    }

    @Test(arguments: 0 ..< 14)
    func theEntranceIsAUniformlyRandomSequenceButCelebrate(_ k: Int) {
        let random = ScriptedRandom([14: [k]])
        let engine = ClawdEngine(random: random, now: t0)
        #expect(random.asked == [14])
        let reference = ClawdEngine.settled()
        reference.perform(.act(Self.entranceActs[k]))
        for _ in 0 ..< 25 { #expect(engine.step(env()) == reference.step(env())) }
    }
}
