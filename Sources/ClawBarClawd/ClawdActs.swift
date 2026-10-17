import Foundation
import ClawBarShared

/// One tick's frame record ($f in Step-Mascot): the sprite pose plus what moves the box and the soul.
struct TickFrame {
    var pose: ClawdPose
    /// Pixels the box rises above its resting place.
    var lift = 0.0
    /// The soul's height above the mouth; drawn when above 0.5.
    var soul = 0.0
    var soulT = 0
}

/// Step-MascotAct's per-frame rules.
enum ClawdActFrames {
    static func isSequence(_ act: ClawdAct) -> Bool { ClawdTables.sequences[act] != nil }

    static func length(_ act: ClawdAct) -> Int { ClawdTables.actLengths[act] ?? 1 }

    /// Writes frame `t` of `act` into `f` and returns the bubble above the head.
    static func apply(_ act: ClawdAct, t: Int, to f: inout TickFrame) -> String {
        if let frames = ClawdTables.sequences[act] {
            // Claude Code's sequences: the pose sets the gaze itself.
            let fr = frames[min(t, frames.count - 1)]
            f.pose.eyes = fr.eyes
            f.pose.arms = fr.arms
            f.pose.feet = fr.feet
            f.pose.off = fr.off
            f.pose.x = fr.x
            f.pose.facing = fr.facing
            f.pose.poof = fr.poof
            f.pose.shadow = fr.shadow
            f.pose.look = 0
            return act == .celebrate ? "!" : ""
        }
        let dig = ClawdTables.burrowDig
        switch act {
        case .wave:
            f.pose.look = 0
            f.pose.eyes = .happy
            f.pose.arms = (t / 4) % 2 != 0 ? .down : .right
        case .stretch:
            if t >= 4, t < 18 {
                f.pose.arms = .up
                f.pose.eyes = .closed
                f.lift = 1.5
            }
        case .yawn:
            f.pose.look = 0
            f.pose.eyes = (3 ..< 17).contains(t) ? .yawn : .closed
        case .stumble:
            // Flops down (crouched, legs hidden), then gets up and stares, stunned.
            if t < 12 {
                f.pose.off = 1
                f.pose.eyes = .closed
            } else {
                f.pose.eyes = .wide
            }
            f.pose.look = 0
        case .soul:
            soul(t: t, &f)
        case .burrow:
            if t < 4 {
                f.pose.look = t < 2 ? -1 : 1
            } else if t < 24 {
                f.pose.look = 0
                f.pose.eyes = .focus
                f.pose.dig = min(dig, Int((Double(t - 4) / 3.5).rounded(.down)))
                let odd = (t / 2) % 2 != 0
                f.pose.feet = odd ? .left : .right
                f.pose.arms = odd ? .up : .down
                f.pose.spray = t % 3 + 1
            } else {
                f.pose.look = 0
                f.pose.dig = dig
                f.pose.eyes = t < 27 ? .blink : .closed
            }
        case .unburrow:
            f.pose.look = 0
            if t < 3 {
                f.pose.dig = dig
                f.pose.eyes = .wide
            } else if t < 9 {
                f.pose.dig = max(0, dig - (t - 3))
                f.pose.eyes = .wide
                f.pose.arms = .up
                f.pose.spray = t % 3 + 1
                if t == 8 { f.lift = 2 }
            } else if t < 21 {
                f.pose.eyes = .closed
                let odd = (t / 2) % 2 != 0
                f.pose.look = odd ? -1 : 1
                f.pose.feet = odd ? .left : .right
                if t < 15 { f.pose.spray = t % 3 + 1 }
            } else if t < 23 {
                f.pose.eyes = .blink
            }
        case .stir:
            f.pose.dig = t < 15 ? dig - 1 : dig
            if t < 3 {
                f.pose.eyes = .wide
                f.pose.look = 0
            } else if t < 13 {
                f.pose.look = t < 8 ? -1 : 1
            } else if t < 17 {
                f.pose.eyes = .blink
                f.pose.look = 0
            } else {
                f.pose.eyes = .closed
                f.pose.look = 0
            }
        default:
            break
        }
        return ""
    }

    /// The soul flies out of the open mouth on a thread, hangs over the body, is sucked back, and the body twitches.
    private static func soul(t: Int, _ f: inout TickFrame) {
        let up = ClawdTables.soulUp, back = ClawdTables.soulBack, top = ClawdTables.soulTop
        f.pose.flip = true
        f.pose.look = 0
        if t < 6 {
            f.pose.eyes = .x
            f.pose.feet = t % 2 != 0 ? .left : .right
        } else if t < back + 6 {
            f.pose.eyes = .gasp
            f.soulT = t
            if t < up {
                let k = Double(t - 6) / (Double(up) - 6)
                f.soul = top * (1 - (1 - k) * (1 - k))
            } else if t < back {
                f.soul = top + 1.5 * sin(Double(t - up) / 2.5)
            } else {
                let k = Double(t - back) / 6
                f.soul = top * (1 - k * k)
            }
        } else if t < back + 9 {
            f.pose.eyes = .wide
            f.lift = 2.5
        } else {
            f.pose.eyes = .x
        }
    }
}
