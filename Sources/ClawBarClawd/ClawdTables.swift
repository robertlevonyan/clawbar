// Transcribed programmatically from the original 1.3.0 (lib/mascot.ps1, lib/hearts.ps1, lib/mascot-menu.ps1, widget.xaml),
// never retyped: the sequences are the expanded New-ClawdFrames calls. Checked against visuals-verbatim.txt.
import ClawBarShared

enum ClawdEyes: String, CaseIterable, Sendable {
    case open, left, right, closed, blink, wink, happy, focus, wide, x, yawn, gasp
}

enum ClawdArms: String, CaseIterable, Sendable {
    case down, up, right, left
}

enum ClawdFeet: String, CaseIterable, Sendable {
    case both, left, right
}

/// The turn-in-place poses (`face:<name>` in the sequences).
enum ClawdFacing: String, CaseIterable, Sendable {
    case right12 = "right-12"
    case right30 = "right-30"
    case right55 = "right-55"
    case right75 = "right-75"
    case edge
    case back105 = "back-105"
    case back125 = "back-125"
    case back150 = "back-150"
    case back
    case left75 = "left-75"
    case left55 = "left-55"
    case left30 = "left-30"
    case left12 = "left-12"
}

/// Dust puffs at the sides while crouched.
enum ClawdPoof: String, Sendable {
    case dot, wave
}

/// The coin hop's shadow.
enum ClawdShadow: String, Sendable {
    case wide, narrow
}

struct ArmGlyphs: Sendable {
    let r1L: String, r1R: String, r2L: String, r2R: String
}

/// One glyph row of a facing pose: characters `from ..< to` are painted in 'eyes' mode.
struct FacingRow: Sendable {
    let glyphs: String, from: Int, to: Int
}

/// A black eye pixel, offset from the eye cell's origin.
struct EyeDot: Sendable, Hashable {
    let dx: Int, dy: Int
}

/// One frame of a Claude Code sequence: New-ClawdFrames' record.
struct SeqFrame: Sendable, Hashable {
    var eyes: ClawdEyes
    var arms: ClawdArms
    var feet: ClawdFeet
    var off = 0
    var x = 0
    var facing: ClawdFacing?
    var poof: ClawdPoof?
    var shadow: ClawdShadow?
}

/// One row of $HealthTiers.
struct HealthTier: Sendable {
    var speed: Double
    var hop: Int?
    var yawn: Int?
    var eyes: ClawdEyes?
    var sweat = false
    var stagger = false
    var stumble: Int?
}

/// One entry of $MascotDemo.
enum DemoEntry: Sendable, Hashable {
    case mood(Mood)
    /// The mood with forceCrit.
    case crit(Mood)
    case drain
    case act(ClawdAct)
}

enum ClawdTables {
    static let cols = 9
    static let rows = 3
    /// The pixel grid: 2 × 4 pixels per glyph cell.
    static let width = 18
    static let height = 12
    static let px = 2.0
    static let py = 2.2
    /// The sprite box: 36 × 26.4.
    static let boxWidth = 36.0
    static let boxHeight = 26.4
    /// How far the box hangs below the ground line.
    static let sink = 4.4
    static let burrowDig = 4
    static let sequenceFrameMs = 60
    static let soulUp = 26
    static let soulBack = 48
    static let soulTop = 20.0
    static let soulPx = 1.4
    static let drainStep = 22
    static let drainLength = 167
    /// widget.xaml: the sweat drop inside the sprite box, and the bubble's centred box.
    static let sweatWidth = 3.0
    static let sweatHeight = 4.5
    static let bubbleWidth = 12.0
    static let bubbleFontSize = 11.0

    /// Glyph → quadrant bits: 1 top-left, 2 top-right, 4 bottom-left, 8 bottom-right.
    static let quadrants: [Character: Int] = [
        " ": 0,
        "█": 15,
        "▀": 3,
        "▄": 12,
        "▌": 5,
        "▐": 10,
        "▘": 1,
        "▝": 2,
        "▖": 4,
        "▗": 8,
        "▛": 7,
        "▜": 11,
        "▙": 13,
        "▟": 14,
    ]

    static let arms: [ClawdArms: ArmGlyphs] = [
        .down: ArmGlyphs(r1L: " ▐", r1R: "", r2L: "▝▜", r2R: "█▀"),
        .up: ArmGlyphs(r1L: "▗▟", r1R: "▄", r2L: " ▜", r2R: "█▘"),
        .right: ArmGlyphs(r1L: " ▐", r1R: "▄", r2L: "▝▜", r2R: "█▘"),
        .left: ArmGlyphs(r1L: "▗▟", r1R: "", r2L: " ▜", r2R: "█▀"),
    ]

    static let feet: [ClawdFeet: String] = [
        .both: " ▝▝   ▝▝ ",
        .left: " ▝▝      ",
        .right: "      ▝▝ ",
    ]

    static let facing: [ClawdFacing: [FacingRow]] = [
        .right12: [
            FacingRow(glyphs: " ▐█▜██▛█ ", from: 2, to: 8),
            FacingRow(glyphs: "▝▜██████▀", from: 2, to: 7),
            FacingRow(glyphs: " ▝▝   ▝▝ ", from: 0, to: 0),
        ],
        .right30: [
            FacingRow(glyphs: "  █▛██▛▌ ", from: 2, to: 7),
            FacingRow(glyphs: " ▝█████▛ ", from: 2, to: 7),
            FacingRow(glyphs: "  ▘▘  ▘▘ ", from: 0, to: 0),
        ],
        .right55: [
            FacingRow(glyphs: "  ▐█▛█▜  ", from: 3, to: 7),
            FacingRow(glyphs: "  ▐████  ", from: 3, to: 7),
            FacingRow(glyphs: "  ▝▝ ▝▝  ", from: 0, to: 0),
        ],
        .right75: [
            FacingRow(glyphs: "   ██▛▌  ", from: 3, to: 6),
            FacingRow(glyphs: "   ███▌  ", from: 3, to: 6),
            FacingRow(glyphs: "   ▘  ▘  ", from: 0, to: 0),
        ],
        .edge: [
            FacingRow(glyphs: "   ▐██   ", from: 4, to: 6),
            FacingRow(glyphs: "   ▐██   ", from: 4, to: 6),
            FacingRow(glyphs: "   ▝ ▝   ", from: 0, to: 0),
        ],
        .back105: [
            FacingRow(glyphs: "   ███▌  ", from: 3, to: 6),
            FacingRow(glyphs: "   ███▌  ", from: 3, to: 6),
            FacingRow(glyphs: "   ▘  ▘  ", from: 0, to: 0),
        ],
        .back125: [
            FacingRow(glyphs: "  ▐████  ", from: 3, to: 7),
            FacingRow(glyphs: "  ▐████  ", from: 3, to: 7),
            FacingRow(glyphs: "  ▝▝ ▝▝  ", from: 0, to: 0),
        ],
        .back150: [
            FacingRow(glyphs: "  █████▌ ", from: 2, to: 7),
            FacingRow(glyphs: " ▝█████▛ ", from: 2, to: 7),
            FacingRow(glyphs: "  ▘▘  ▘▘ ", from: 0, to: 0),
        ],
        .back: [
            FacingRow(glyphs: " ▐██████ ", from: 2, to: 8),
            FacingRow(glyphs: "▝▜██████▀", from: 2, to: 7),
            FacingRow(glyphs: " ▝▝   ▝▝ ", from: 0, to: 0),
        ],
        .left75: [
            FacingRow(glyphs: "   ▛██▌  ", from: 3, to: 6),
            FacingRow(glyphs: "   ███▌  ", from: 3, to: 6),
            FacingRow(glyphs: "   ▘  ▘  ", from: 0, to: 0),
        ],
        .left55: [
            FacingRow(glyphs: "  ▐▜▛██  ", from: 3, to: 7),
            FacingRow(glyphs: "  ▐████  ", from: 3, to: 7),
            FacingRow(glyphs: "  ▝▝ ▝▝  ", from: 0, to: 0),
        ],
        .left30: [
            FacingRow(glyphs: "  ▛██▛█▌ ", from: 2, to: 7),
            FacingRow(glyphs: " ▝█████▛ ", from: 2, to: 7),
            FacingRow(glyphs: "  ▘▘  ▘▘ ", from: 0, to: 0),
        ],
        .left12: [
            FacingRow(glyphs: " ▐▛███▜█ ", from: 2, to: 8),
            FacingRow(glyphs: "▝▜██████▀", from: 2, to: 7),
            FacingRow(glyphs: " ▝▝   ▝▝ ", from: 0, to: 0),
        ],
    ]

    /// One shape for both eyes, or left and right (wink).
    static let eyeShapes: [ClawdEyes: [[EyeDot]]] = [
        .open: [[EyeDot(dx: 1, dy: 2), EyeDot(dx: 1, dy: 3)]],
        .left: [[EyeDot(dx: 0, dy: 0), EyeDot(dx: 0, dy: 1)]],
        .right: [[EyeDot(dx: 2, dy: 0), EyeDot(dx: 2, dy: 1)]],
        .closed: [[EyeDot(dx: 0, dy: 3), EyeDot(dx: 1, dy: 3)]],
        .blink: [[EyeDot(dx: 0, dy: 3), EyeDot(dx: 1, dy: 3)]],
        .wink: [[EyeDot(dx: 1, dy: 2), EyeDot(dx: 1, dy: 3)], [EyeDot(dx: 0, dy: 3), EyeDot(dx: 1, dy: 3)]],
        .happy: [[EyeDot(dx: 0, dy: 3), EyeDot(dx: 1, dy: 2), EyeDot(dx: 2, dy: 3)]],
        .focus: [[EyeDot(dx: 1, dy: 3)]],
        .wide: [[EyeDot(dx: 0, dy: 1), EyeDot(dx: 1, dy: 1), EyeDot(dx: 0, dy: 2), EyeDot(dx: 1, dy: 2), EyeDot(dx: 0, dy: 3), EyeDot(dx: 1, dy: 3)]],
        .x: [[EyeDot(dx: 0, dy: 1), EyeDot(dx: 2, dy: 1), EyeDot(dx: 1, dy: 2), EyeDot(dx: 0, dy: 3), EyeDot(dx: 2, dy: 3)]],
        .yawn: [[EyeDot(dx: 0, dy: 3), EyeDot(dx: 1, dy: 3)]],
        .gasp: [[EyeDot(dx: 0, dy: 1), EyeDot(dx: 2, dy: 1), EyeDot(dx: 1, dy: 2), EyeDot(dx: 0, dy: 3), EyeDot(dx: 2, dy: 3)]],
    ]

    private static let seqJump: [SeqFrame] = [
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .dot),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .wave),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .dot),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .wave),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqLook: [SeqFrame] = [
        SeqFrame(eyes: .right, arms: .down, feet: .both),
        SeqFrame(eyes: .right, arms: .down, feet: .both),
        SeqFrame(eyes: .right, arms: .down, feet: .both),
        SeqFrame(eyes: .right, arms: .down, feet: .both),
        SeqFrame(eyes: .right, arms: .down, feet: .both),
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqCelebrate: [SeqFrame] = [
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .dot),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .wave),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .dot),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .wave),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1),
    ]

    private static let seqSkip: [SeqFrame] = [
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, x: -9),
        SeqFrame(eyes: .open, arms: .up, feet: .both, x: -6),
        SeqFrame(eyes: .open, arms: .up, feet: .both, x: -6),
        SeqFrame(eyes: .open, arms: .down, feet: .both, x: -6),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, x: -6),
        SeqFrame(eyes: .open, arms: .up, feet: .both, x: -3),
        SeqFrame(eyes: .open, arms: .up, feet: .both, x: -3),
        SeqFrame(eyes: .open, arms: .down, feet: .both, x: -3),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, x: -3),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .dot),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .wave),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqSpin: [SeqFrame] = [
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .right, arms: .down, feet: .both),
        SeqFrame(eyes: .right, arms: .down, feet: .both),
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqPeekaboo: [SeqFrame] = [
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 3),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 2),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 2),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 2),
        SeqFrame(eyes: .right, arms: .down, feet: .both, off: 2),
        SeqFrame(eyes: .right, arms: .down, feet: .both, off: 2),
        SeqFrame(eyes: .right, arms: .down, feet: .both, off: 2),
        SeqFrame(eyes: .left, arms: .down, feet: .both, off: 2),
        SeqFrame(eyes: .left, arms: .down, feet: .both, off: 2),
        SeqFrame(eyes: .left, arms: .down, feet: .both, off: 2),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 2),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 2),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .closed, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqDrop: [SeqFrame] = [
        SeqFrame(eyes: .open, arms: .up, feet: .both, off: -3),
        SeqFrame(eyes: .open, arms: .up, feet: .both, off: -2),
        SeqFrame(eyes: .open, arms: .up, feet: .both, off: -2),
        SeqFrame(eyes: .open, arms: .up, feet: .both, off: -1),
        SeqFrame(eyes: .open, arms: .up, feet: .both, off: -1),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .dot),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .wave),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .closed, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqWaddle: [SeqFrame] = [
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -9),
        SeqFrame(eyes: .right, arms: .down, feet: .left, x: -6),
        SeqFrame(eyes: .right, arms: .down, feet: .left, x: -6),
        SeqFrame(eyes: .right, arms: .down, feet: .right, x: -5),
        SeqFrame(eyes: .right, arms: .down, feet: .right, x: -5),
        SeqFrame(eyes: .right, arms: .down, feet: .left, x: -4),
        SeqFrame(eyes: .right, arms: .down, feet: .left, x: -4),
        SeqFrame(eyes: .right, arms: .down, feet: .right, x: -3),
        SeqFrame(eyes: .right, arms: .down, feet: .right, x: -3),
        SeqFrame(eyes: .right, arms: .down, feet: .left, x: -2),
        SeqFrame(eyes: .right, arms: .down, feet: .left, x: -2),
        SeqFrame(eyes: .right, arms: .down, feet: .right, x: -1),
        SeqFrame(eyes: .right, arms: .down, feet: .right, x: -1),
        SeqFrame(eyes: .right, arms: .down, feet: .both),
        SeqFrame(eyes: .right, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .closed, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqPeek: [SeqFrame] = [
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -9),
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -6),
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -6),
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -6),
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -6),
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -6),
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -9),
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -9),
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -9),
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -5),
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -5),
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -5),
        SeqFrame(eyes: .right, arms: .down, feet: .both, x: -5),
        SeqFrame(eyes: .open, arms: .up, feet: .both, x: -3),
        SeqFrame(eyes: .open, arms: .up, feet: .both, x: -3),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .dot),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .wave),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqWink: [SeqFrame] = [
        SeqFrame(eyes: .wink, arms: .down, feet: .both),
        SeqFrame(eyes: .wink, arms: .down, feet: .both),
        SeqFrame(eyes: .wink, arms: .down, feet: .both),
        SeqFrame(eyes: .wink, arms: .down, feet: .both),
        SeqFrame(eyes: .wink, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqBoop: [SeqFrame] = [
        SeqFrame(eyes: .closed, arms: .down, feet: .both, off: 1, poof: .dot),
        SeqFrame(eyes: .closed, arms: .down, feet: .both, off: 1, poof: .wave),
        SeqFrame(eyes: .closed, arms: .down, feet: .both, off: 1, poof: .wave),
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .left, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .closed, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqTap: [SeqFrame] = [
        SeqFrame(eyes: .open, arms: .down, feet: .left),
        SeqFrame(eyes: .open, arms: .down, feet: .left),
        SeqFrame(eyes: .open, arms: .down, feet: .right),
        SeqFrame(eyes: .open, arms: .down, feet: .right),
        SeqFrame(eyes: .open, arms: .down, feet: .left),
        SeqFrame(eyes: .open, arms: .down, feet: .left),
        SeqFrame(eyes: .open, arms: .down, feet: .right),
        SeqFrame(eyes: .open, arms: .down, feet: .right),
        SeqFrame(eyes: .open, arms: .down, feet: .left),
        SeqFrame(eyes: .open, arms: .down, feet: .right),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .up, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqSneeze: [SeqFrame] = [
        SeqFrame(eyes: .closed, arms: .up, feet: .both),
        SeqFrame(eyes: .closed, arms: .up, feet: .both),
        SeqFrame(eyes: .closed, arms: .up, feet: .both),
        SeqFrame(eyes: .closed, arms: .up, feet: .both),
        SeqFrame(eyes: .closed, arms: .down, feet: .both, off: 1, poof: .wave),
        SeqFrame(eyes: .closed, arms: .down, feet: .both, off: 1, poof: .wave),
        SeqFrame(eyes: .closed, arms: .down, feet: .both),
        SeqFrame(eyes: .closed, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
        SeqFrame(eyes: .closed, arms: .down, feet: .both),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqTurn: [SeqFrame] = [
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .right12),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .right30),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .right55),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .right75),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .edge),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .back105),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .back125),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .back150),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .back),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .back),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .back150),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .back125),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .back105),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .edge),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .left75),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .left55),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .left30),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .left12),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    private static let seqCoinHop: [SeqFrame] = [
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1),
        SeqFrame(eyes: .open, arms: .up, feet: .both, shadow: .wide),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .right55, shadow: .narrow),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .edge, shadow: .narrow),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .back125, shadow: .narrow),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .back, shadow: .narrow),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .back125, shadow: .narrow),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .edge, shadow: .narrow),
        SeqFrame(eyes: .open, arms: .down, feet: .both, facing: .left55, shadow: .narrow),
        SeqFrame(eyes: .open, arms: .up, feet: .both, shadow: .wide),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .dot),
        SeqFrame(eyes: .open, arms: .down, feet: .both, off: 1, poof: .wave),
        SeqFrame(eyes: .open, arms: .down, feet: .both),
    ]

    /// The 15 Claude Code sequences ($ClawdSeqs), one 60 ms frame each.
    static let sequences: [ClawdAct: [SeqFrame]] = [
        .jump: seqJump,
        .look: seqLook,
        .celebrate: seqCelebrate,
        .skip: seqSkip,
        .spin: seqSpin,
        .peekaboo: seqPeekaboo,
        .drop: seqDrop,
        .waddle: seqWaddle,
        .peek: seqPeek,
        .wink: seqWink,
        .boop: seqBoop,
        .tap: seqTap,
        .sneeze: seqSneeze,
        .turn: seqTurn,
        .coinHop: seqCoinHop,
    ]

    /// Every act's length in ticks, in $MascotActs order.
    static let actLengths: [ClawdAct: Int] = [
        .jump: 12,
        .look: 11,
        .celebrate: 15,
        .skip: 14,
        .spin: 10,
        .peekaboo: 21,
        .drop: 13,
        .waddle: 19,
        .peek: 20,
        .wink: 6,
        .boop: 11,
        .tap: 14,
        .sneeze: 12,
        .turn: 19,
        .coinHop: 14,
        .wave: 24,
        .stretch: 22,
        .yawn: 22,
        .stumble: 20,
        .soul: 66,
        .burrow: 30,
        .unburrow: 28,
        .stir: 22,
    ]

    /// Sequences that start in place, except celebrate.
    static let clickActs: [ClawdAct] = [.jump, .look, .spin, .peekaboo, .drop, .wink, .boop, .tap, .sneeze, .turn, .coinHop]
    /// Every sequence except celebrate.
    static let entranceActs: [ClawdAct] = [.jump, .look, .skip, .spin, .peekaboo, .drop, .waddle, .peek, .wink, .boop, .tap, .sneeze, .turn, .coinHop]

    static let demo: [DemoEntry] = [
        .mood(.sleep),
        .mood(.doze),
        .mood(.idle),
        .mood(.work),
        .crit(.work),
        .mood(.wait),
        .drain,
        .act(.jump),
        .act(.look),
        .act(.celebrate),
        .act(.skip),
        .act(.spin),
        .act(.peekaboo),
        .act(.drop),
        .act(.waddle),
        .act(.peek),
        .act(.wink),
        .act(.boop),
        .act(.tap),
        .act(.sneeze),
        .act(.turn),
        .act(.coinHop),
        .act(.wave),
        .act(.stretch),
        .act(.yawn),
        .act(.stumble),
        .act(.soul),
    ]

    static let soulArt: [String] = [
        "..########..",
        "..#.####.#..",
        "############",
        "..########..",
        "...######...",
        "....####....",
        ".....##.....",
    ]

    /// $HealthTiers, indexed by halves.
    static let healthTiers: [HealthTier] = [
        HealthTier(speed: 0.0),
        HealthTier(speed: 0.35, eyes: .blink, sweat: true, stagger: true, stumble: 220),
        HealthTier(speed: 0.55, yawn: 160, eyes: .focus, sweat: true),
        HealthTier(speed: 0.75, yawn: 200, eyes: .focus),
        HealthTier(speed: 0.9, yawn: 350),
        HealthTier(speed: 1.0),
        HealthTier(speed: 1.25, hop: 300),
    ]

    /// The Hearts submenu after "from the limit": halves and their (unlocalized) labels.
    static let devMenuHearts: [(halves: Int, label: String)] = [
        (6, "3"),
        (5, "2½"),
        (4, "2"),
        (3, "1½"),
        (2, "1"),
        (1, "½"),
        (0, "0"),
    ]
}
