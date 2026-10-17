import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import ClawBarClawd
import ClawBarPresenter
import ClawBarShared
import ClawBarSky

/// record-gif.ps1's `S name state for`.
struct FakeSession: Equatable {
    var name: String
    var state: SessionState
    var waitingFor: String?

    init(_ name: String, _ state: SessionState = .idle, waitingFor: String? = nil) {
        self.name = name
        self.state = state
        self.waitingFor = waitingFor
    }
}

enum ScenarioAction: Equatable {
    /// Set-Sky: a forced phase and weather code.
    case sky(SkyPhase, Int)
    /// Set-Usage: the session %, its reset that many minutes away, week 41 and Fable 18.
    case usage(Int, resetMinutes: Double)
    case sessions([FakeSession])
    case click
    /// `$script:Mz.drainT = 0`: Play losing hearts.
    case drain
}

struct ScenarioStep: Equatable {
    var at: Double
    var actions: [ScenarioAction]
}

struct ScenarioScript {
    var steps: [ScenarioStep]
    /// Crop below the reset line, as every scenario but the tour does.
    var crop: Bool
    /// The last step's time ends the recording.
    var length: Double { steps.last?.at ?? 0 }
}

/// tools/record-gif.ps1's scenarios, step for step.
enum Scenarios {
    static func script(_ s: RecordScenario) -> ScenarioScript {
        func S(_ name: String, _ state: SessionState = .idle, _ waitingFor: String? = nil) -> FakeSession {
            FakeSession(name, state, waitingFor: waitingFor)
        }
        func step(_ at: Double, _ actions: ScenarioAction...) -> ScenarioStep { ScenarioStep(at: at, actions: actions) }
        func usage(_ pct: Int, _ resetMinutes: Double = 192) -> ScenarioAction { .usage(pct, resetMinutes: resetMinutes) }
        switch s {
        case .tour:
            return ScenarioScript(steps: [
                step(0, .sky(.day, 2), usage(34), .sessions([S("api"), S("web")])),
                step(2.5, .sessions([S("api", .busy), S("web")])),
                step(4, usage(36)), step(5.5, usage(39)), step(7, usage(42)),
                step(8.5, .sessions([S("api"), S("web")])),
                step(10.5, .sessions([S("api"), S("web", .waiting, "permission")])),
                step(14.5),
            ], crop: false)
        case .sleep:
            return ScenarioScript(steps: [
                step(0, .sky(.night, 0), usage(12), .sessions([S("api")])),
                step(1.5, .sessions([])),
                step(9),
            ], crop: true)
        case .limit:
            return ScenarioScript(steps: [
                step(0, .sky(.day, 3), usage(100), .sessions([S("api")])),
                step(2, .click),
                step(9.5),
            ], crop: true)
        case .reset:
            return ScenarioScript(steps: [
                step(0, .sky(.day, 1), usage(96, 3), .sessions([S("api", .busy)])),
                step(4, usage(0, 300)),
                step(8.5),
            ], crop: true)
        case .hearts:
            return ScenarioScript(steps: [
                step(0, .sky(.dusk, 2), usage(10), .sessions([S("api", .busy)]), .drain),
                step(15.5),
            ], crop: true)
        case .weather:
            return ScenarioScript(steps: [
                step(0, .sky(.day, 63), usage(27), .sessions([S("api")])),
                step(3, .sky(.night, 73)),
                step(6, .sky(.dusk, 95)),
                step(9, .sky(.dawn, 2)),
                step(12),
            ], crop: true)
        case .clicks:
            return ScenarioScript(steps: [
                step(0, .sky(.day, 1), usage(22), .sessions([S("api")])),
                step(1, .click), step(3.5, .click), step(6, .click), step(8.5, .click),
                step(11),
            ], crop: true)
        }
    }
}

/// Plays a script on the original's clock: scenario time is frames × 0.09 s, whatever the tick interval.
final class ScenarioPlayer {
    let script: ScenarioScript
    private var next = 0
    private(set) var skyDev = SkyDevState()
    private var pct: Int?
    private var sessionReset: Date?
    private var weekReset: Date?
    private var usageAt: Date?
    private var sessions: [FakeSession] = []

    init(_ script: ScenarioScript) {
        self.script = script
    }

    var finished: Bool { next >= script.steps.count }

    static func time(frame n: Int) -> Double { Double(n) * 0.09 }

    /// record-gif.ps1 captures a frame on every tick until the last step is due.
    static func frameCount(_ script: ScenarioScript) -> Int {
        var n = 0
        while time(frame: n) < script.length { n += 1 }
        return n
    }

    /// Applies every step due by frame `n`; returns the actions, in order.
    func advance(frame n: Int, now: Date) -> [ScenarioAction] {
        let t = Self.time(frame: n)
        var applied: [ScenarioAction] = []
        while next < script.steps.count, script.steps[next].at <= t {
            for a in script.steps[next].actions {
                apply(a, now: now)
                applied.append(a)
            }
            next += 1
        }
        return applied
    }

    private func apply(_ a: ScenarioAction, now: Date) {
        switch a {
        case let .sky(phase, code):
            skyDev = SkyDevState(phase: phase, weatherCode: code)
        case let .usage(p, minutes):
            pct = p
            sessionReset = now.addingTimeInterval(minutes * 60)
            weekReset = now.addingTimeInterval(2.4 * 86400)
            usageAt = now
        case let .sessions(s):
            sessions = s
        case .click, .drain:
            break
        }
    }

    /// The fake data, with a fresh status so the line never says loading.
    func snapshot(now: Date) -> DataSnapshot {
        let usage = pct.map { p in
            UsageSnapshot(
                sessionPercent: p, weekPercent: 41, sessionReset: sessionReset, weekReset: weekReset,
                modelWeeks: [ModelWeek(name: "Fable", percent: 18, reset: weekReset)]
            )
        }
        return DataSnapshot(
            usage: usage, usageAt: usageAt, usageProbeCompleted: true,
            sessions: sessions.enumerated().map { i, s in
                SessionInfo(
                    pid: Int32(4200 + i), name: s.name, cwd: "\(Samples.home)/code/\(s.name)", state: s.state,
                    waitingFor: s.waitingFor, kind: "interactive"
                )
            },
            sessionsRead: true, status: ServiceStatus(indicator: "none"), statusAt: now
        )
    }
}

/// `--record <scenario> <gif>`: record-gif.ps1 with a seeded RNG and a virtual clock, then compose-gif.py's framing.
enum Recorder {
    /// record-gif.ps1's config.json.
    static let config = Config(
        language: "en", scale: 1.0, topmost: true, expanded: false, showStats: false, showStatus: true,
        showSessions: true, showAccount: false, left: 40, top: 40
    )
    static let backdrop = RGBA(r: 13, g: 17, b: 23)

    static func run(_ scenario: RecordScenario, gif: URL) -> Int32 {
        let frames = record(scenario)
        do {
            try GIFWriter.write(frames, delay: 0.09, to: gif)
            print("wrote \(gif.path): \(frames.count) frames")
            return 0
        } catch {
            FileHandle.standardError.write(Data("ClawBar: \(error)\n".utf8))
            return 1
        }
    }

    static func record(_ s: RecordScenario, maxFrames: Int = .max, seed: UInt64 = 42) -> [CGImage] {
        let script = Scenarios.script(s)
        var now = Samples.now
        let player = ScenarioPlayer(script)
        // One generator for both, like the original's shared $script:Rnd.
        let random = SeededRandomSource(seed: seed)
        let clawd = ClawdEngine(random: random, now: now)
        let sky = SkyEngine(random: random)
        let layout = LayoutModel()
        var view = presenter(player.snapshot(now: now), now: now)
        // Update-Texts renders once before the first tick, with no data yet.
        clawd.apply(ClawdDataInput(player.snapshot(now: now), critPercent: config.critPercent), now: now)
        _ = CardRenderer.render(CardRenderer.Scene(view: view), scale: 1, layout: layout)

        var cards: [CGImage] = []
        var cropHeight: Int?
        var n = 0
        while cards.count < maxFrames {
            // The mascot timer's own handler first, then record-gif.ps1's: due steps, Update-Widget, capture.
            var frame = clawd.step(ClawdStepEnv(
                areaWidth: PlayArea.width(numberWidth: layout.numberWidth), areaHeight: PlayArea.height,
                mouseOverWindow: false, mouseX: nil, now: now, lang: .en
            ))
            // The recorder collapses the developer caption.
            frame.devCaption = ""
            let skyFrame = sky.step(size: CGSize(width: CardView.content, height: PlayArea.height), inputs: skyInputs(player, now: now))
            let applied = player.advance(frame: n, now: now)
            for a in applied {
                switch a {
                case .click: clawd.click(now: now)
                case .drain: clawd.startDrain()
                case .sky: sky.invalidate()
                case .usage, .sessions: break
                }
            }
            if !applied.isEmpty {
                let snapshot = player.snapshot(now: now)
                view = presenter(snapshot, now: now)
                clawd.apply(ClawdDataInput(snapshot, critPercent: config.critPercent), now: now)
            }
            if player.finished { break }
            guard let card = CardRenderer.render(CardRenderer.Scene(view: view, clawd: frame, sky: skyFrame), scale: 1, layout: layout) else { break }
            if script.crop, cropHeight == nil, let reset = layout.rects[.reset] {
                cropHeight = Int(((reset.maxY + 9) * 2).rounded(.up))
            }
            cards.append(card)
            now = now.addingTimeInterval(Double(clawd.tickMilliseconds) / 1000)
            n += 1
        }
        return compose(cards, cropHeight: script.crop ? cropHeight : nil)
    }

    private static func presenter(_ data: DataSnapshot, now: Date) -> WidgetViewState {
        WidgetPresenter.make(PresenterInput(
            config: config, now: now, timeZone: Samples.timeZone, data: data, appVersion: AppInfo.version, homeDirectory: Samples.home
        ))
    }

    private static func skyInputs(_ player: ScenarioPlayer, now: Date) -> SkyInputs {
        SkyInfo.inputs(nil, place: nil, now: now, localZone: Samples.timeZone, dev: player.skyDev)
    }

    /// compose-gif.py: every frame on one GitHub-dark canvas the size of the largest, 24 px of padding, scaled by 1/1.5.
    static func compose(_ cards: [CGImage], cropHeight: Int?) -> [CGImage] {
        let pad = 24
        let w = cards.map(\.width).max() ?? 0
        let h = cards.map { min($0.height, cropHeight ?? $0.height) }.max() ?? 0
        return cards.compactMap { card in
            guard let ctx = Imaging.context(width: w + 2 * pad, height: h + 2 * pad) else { return nil }
            ctx.setFillColor(cgColor(backdrop))
            ctx.fill(CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
            // y-up: the card's top row sits `pad` below the canvas top; a crop clips away its bottom.
            ctx.clip(to: CGRect(x: pad, y: pad, width: w, height: h))
            ctx.draw(card, in: CGRect(x: pad, y: pad + h - card.height, width: card.width, height: card.height))
            return ctx.makeImage().flatMap { Imaging.scaled($0, by: 1 / 1.5) }
        }
    }
}

enum GIFWriter {
    /// A looping GIF with one delay for every frame, like ffmpeg's `-framerate 1/0.09` in compose-gif.py.
    static func write(_ frames: [CGImage], delay: Double, to url: URL) throws {
        guard !frames.isEmpty,
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil)
        else { throw CLIError(message: "cannot write \(url.path)") }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let props = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay],
        ] as CFDictionary
        for f in frames { CGImageDestinationAddImage(dest, f, props) }
        guard CGImageDestinationFinalize(dest) else { throw CLIError(message: "cannot write \(url.path)") }
    }
}
