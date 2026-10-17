import CoreGraphics
import Foundation
import Testing
@testable import ClawBarClawd
import ClawBarShared

/// The ops of one frame: the original's child order and the brief's coordinates
/// (x from the play area's left edge, y down from the ground line).
@Suite struct FrameLayoutTests {
    enum Kind: Int, Comparable {
        case body, eyes, fx, sand, sweat, z, bubble, love, soul, confetti, dust

        static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }
    }

    static func kinds(_ frame: ClawdFrame) -> [Kind] {
        var seenBody = false, seenEyes = false
        return frame.ops.map { op in
            switch op {
            case .text(let s, _, _, _, _, _, _):
                return s == "z" ? .z : .bubble
            case .rects(let r, let c, _):
                if c == Palette.clawdBody, !seenBody {
                    seenBody = true
                    return .body
                }
                if c == Palette.clawdEyes, !seenEyes {
                    seenEyes = true
                    return .eyes
                }
                if c == Palette.clawdFx { return .fx }
                if c == Palette.sand { return .sand }
                if c == Palette.sweat { return .sweat }
                if c == Palette.soul { return .soul }
                if c == Palette.love, r.count == 7 { return .love }
                if c == Palette.dust, r.count == 1, r[0].size == CGSize(width: 2, height: 2) { return .dust }
                if Palette.confetti.contains(c), r.count == 1 { return .confetti }
                Issue.record("unknown op \(op)")
                return .dust
            default:
                Issue.record("unexpected op \(op)")
                return .dust
            }
        }
    }

    @Test func opsComeInTheOriginalChildOrder() {
        // Celebrating near the limit, just petted: body, eyes, fx, sweat, bubble, love, confetti.
        let party = ClawdEngine.settled()
        party.apply(input(sessions: 1, pct: 40, crit: 40), now: t0)
        party.perform(.act(.celebrate))
        party.click(now: t0)
        let a = Self.kinds(party.step(env()))
        #expect(a == [.body, .eyes, .fx, .sweat, .bubble, .love] + Array(repeating: .confetti, count: 12))

        // The soul over falling confetti, petted, sweating.
        let soul = ClawdEngine.settled()
        soul.apply(input(sessions: 1, pct: 40, crit: 40), now: t0)
        soul.perform(.act(.celebrate))
        soul.step(env())
        soul.perform(.act(.soul))
        soul.click(now: t0)
        let b = Self.kinds(soul.run(8).last!)
        #expect(b == [.body, .eyes, .sweat, .love, .soul] + Array(repeating: .confetti, count: 12))

        // Dozing near the limit: sweat, then the 'z'.
        let doze = ClawdEngine.settled()
        doze.apply(input(sessions: 1, pct: 40, crit: 40), now: t0)
        #expect(Self.kinds(doze.run(10, env(at: t0 + 600)).last!) == [.body, .eyes, .sweat, .z])

        // Burrowing: the sand over body and eyes; running: dust last.
        let burrow = ClawdEngine.settled()
        burrow.apply(input(sessions: 1, pct: 40, crit: 40), now: t0)
        burrow.perform(.act(.burrow))
        #expect(Self.kinds(burrow.run(9).last!) == [.body, .eyes, .sand, .sweat])
        let run = ClawdEngine.settled()
        run.apply(input(busy: 1, pct: 40, crit: 40), now: t0)
        #expect(Self.kinds(run.step(env())) == [.body, .eyes, .sweat, .dust, .dust, .dust])
    }

    @Test func theCaptionGoesAfterTheSoulAndBeforeTheParticles() {
        // MascotTag follows MascotSoul in widget.xaml; the runtime confetti and dust come after it.
        let party = ClawdEngine.settled()
        party.apply(input(sessions: 1, pct: 40, crit: 40), now: t0)
        party.perform(.act(.celebrate))
        party.click(now: t0)
        let frame = party.step(env())
        #expect(frame.captionIndex == 6)
        #expect(Self.kinds(frame)[6] == .confetti)

        let run = ClawdEngine.settled()
        run.apply(input(busy: 1), now: t0)
        let running = run.step(env())
        #expect(running.captionIndex == 2)
        #expect(Self.kinds(running)[2...].allSatisfy { $0 == .dust })
    }

    @Test func theSpriteBoxHangsBelowTheGroundLine() {
        let engine = ClawdEngine.settled()
        let frame = engine.step(env(width: 180))
        // Centred on the first tick: x = (180 − 36) / 2.
        #expect(frame.spriteRect == CGRect(x: 72, y: 4.4 - 26.4, width: 36, height: 26.4))
        #expect(frame.ops == ClawdFrame.sample.ops.map { op in
            guard case .rects(let r, let c, let o) = op else { return op }
            return .rects(r.map { $0.offsetBy(dx: 12, dy: 0) }, c, opacity: o)
        })
        // Narrower than the box: the span is 0.
        #expect(Double(ClawdEngine.settled().step(env(width: 20)).spriteRect.minX) == 0)
    }

    @Test func theZRisesFromBehindTheHead() throws {
        let engine = ClawdEngine.settled()
        engine.apply(input(sessions: 0), now: t0)
        let frames = engine.run(40)
        for n in [31, 35, 39] {
            let z = try #require(FrameView(frames[n - 1]).texts.first { $0.text == "z" })
            let p = Double(n % 30) / 30
            // Dug in: base 9 above the ground, rising 14 over 30 ticks.
            #expect(abs(z.at.x - (72 + 28 + 3 * sin(p * 2 * Double.pi))) < 1e-9)
            #expect(abs(z.at.y - -(9 + 14 * p)) < 1e-9)
            #expect(abs(z.size - (7 + 4 * p)) < 1e-12 && abs(z.opacity - (1 - p)) < 1e-12)
            #expect(z.color == Palette.zzz && z.anchor == .bottomLeading)
        }
        // Dozing on his feet the z starts at 19.
        let doze = ClawdEngine.settled()
        doze.apply(input(sessions: 1), now: t0)
        let z = try #require(FrameView(doze.run(10, env(at: t0 + 600)).last!).texts.first { $0.text == "z" })
        #expect(abs(z.at.y - -(19 + 14 * 10 / 30)) < 1e-9)
    }

    @Test func theBubbleIsCentredOverClawd() throws {
        let engine = ClawdEngine.settled()
        engine.apply(input(waiting: 1), now: t0)
        let frames = engine.run(12)
        for n in [1, 4, 9, 12] {
            let bubble = try #require(FrameView(frames[n - 1]).texts.first)
            let p = n % 40
            let k = Double(p) / 7
            let lift = p < 8 ? 12 * k * (1 - k) : 0
            #expect(bubble.text == "?" && bubble.anchor == .bottom && bubble.size == 11)
            #expect(abs(bubble.at.x - (72 + 18)) < 1e-9)
            #expect(abs(bubble.at.y - -(22 + lift + 1.5 * sin(Double(n) / 3))) < 1e-9)
            #expect(abs(frames[n - 1].spriteRect.minY - (4.4 - lift - 26.4)) < 1e-9)
        }
    }

    @Test func theSweatDropMovesTwiceTheLift() throws {
        // Waiting near the limit hops: the drop's top inside the box subtracts the lift again (quirk 11b).
        let engine = ClawdEngine.settled()
        engine.apply(input(waiting: 1, pct: 40, crit: 40), now: t0)
        let frames = engine.run(25)
        for n in [3, 5, 22] {
            let drop = try #require(FrameView(frames[n - 1]).sweat.first)
            let p = Double(n % 20) / 20
            let k = Double(n % 40) / 7
            let lift = n % 40 < 8 ? 12 * k * (1 - k) : 0
            let box = frames[n - 1].spriteRect
            #expect(drop.rects.count == 1)
            #expect(close(drop.rects[0], CGRect(x: box.minX + 2, y: 4.4 - lift - 26.4 + (-2 + 6 * p - lift), width: 3, height: 4.5)))
            #expect(abs(drop.opacity - (1 - p)) < 1e-12)
        }
        // Looking left puts it on the right side of the box.
        let left = ClawdEngine.settled()
        left.apply(input(waiting: 1, pct: 40, crit: 40), now: t0)
        let drop = try #require(FrameView(left.step(env(over: true, mouseX: 0))).sweat.first)
        #expect(Double(drop.rects[0].minX) == 72 + 31)
    }

    @Test func dustFliesBehindTheRunner() {
        let engine = ClawdEngine.settled()
        engine.apply(input(busy: 1), now: t0)
        let frame = engine.step(env())
        let dust = FrameView(frame).dust
        #expect(dust.count == 3)
        // Running right from x = 72, now at 73.6.
        for (i, d) in dust.enumerated() {
            let p = Double((1 + 3 * i) % 9) / 9
            #expect(close(d.rects[0], CGRect(x: 73.6 + 4 - 8 * p - 2 * Double(i), y: -4 * p - 2, width: 2, height: 2)))
            #expect(abs(d.opacity - 0.7 * (1 - p)) < 1e-12)
        }
    }

    @Test func confettiFallsFlipsAndClearsAfter45Ticks() {
        let engine = ClawdEngine.settled()
        engine.step(env())
        engine.perform(.act(.celebrate))
        let frames = engine.run(46).map(FrameView.init)
        // The scripted source gives x = 72 − 12 + 30, y = 34 + 6, fall 1.5 and no drift.
        let first = frames[0].confetti
        #expect(first.count == 12)
        for (i, c) in first.enumerated() {
            let width = ((2 + i) / 2) % 2 != 0 ? 2.5 : 1.2
            #expect(close(c, CGRect(x: 90, y: -(40 - 1.5) - 2.5, width: width, height: 2.5)))
        }
        // Each piece shows while above the ground: 40 / 1.5 ⇒ 26 ticks.
        #expect(frames[25].confetti.count == 12 && frames[26].confetti.isEmpty)
        #expect(frames[45].confetti.isEmpty)
    }
}
