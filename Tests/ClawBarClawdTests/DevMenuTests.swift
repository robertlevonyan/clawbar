import Foundation
import Testing
@testable import ClawBarClawd
import ClawBarShared

/// mascot-menu.ps1's developer menu: the tree, its actions, and the check marks set on open.
@Suite struct DevMenuTests {
    static func menu(_ dev: ClawdDevState = ClawdDevState(), sky: SkyDevState = SkyDevState(), skyVisible: Bool = true, lang: Lang = .en) -> [DevMenuNode] {
        DevMenu.build(dev: dev, sky: sky, skyVisible: skyVisible, lang: lang)
    }

    static func item(_ nodes: [DevMenuNode], _ title: String) -> DevMenuNode? { nodes.first { $0.title == title } }

    static func checked(_ nodes: [DevMenuNode]) -> [String] { nodes.filter(\.checked).map(\.title) }

    @Test func theTreeInOrder() {
        let top = Self.menu()
        #expect(top.map(\.title) == [
            "Developer mode", "", "Auto (live data)", "State", "Animation", "Sweating near the limit", "Hearts", "Sky", "",
            "Show everything in turn",
        ])
        #expect(top.map(\.isSeparator) == [false, true, false, false, false, false, false, false, true, false])
        #expect(!top[0].enabled && top[0].action == nil)
        #expect(top[2].action == .auto && top[9].action == .demo)
        #expect(top[3].action == nil && top[4].action == nil && top[6].action == nil && top[7].action == nil)
    }

    @Test func theStateAndAnimationSubmenus() {
        let top = Self.menu()
        let states = top[3].children
        #expect(states.map(\.title) == ["sleeping", "dozing", "wandering", "working", "waiting for you", "limit reached"])
        #expect(states.map(\.action) == [.mood(.sleep), .mood(.doze), .mood(.idle), .mood(.work), .mood(.wait), .mood(.dead)])
        let acts = top[4].children
        #expect(acts.map(\.title) == [
            "jump", "looks around", "celebrate", "skip", "spin", "peekaboo", "drops in", "waddle", "peek", "wink", "boop",
            "tap dance", "sneeze", "turn around", "coin hop", "wave", "stretch", "yawn", "stumble", "soul leaves",
            "burrows in", "climbs out of the burrow", "peeks out of the burrow",
        ])
        #expect(acts.map(\.action) == ClawdAct.allCases.map { DevAction.act($0) })
        #expect(acts.allSatisfy { !$0.checked && $0.enabled })
    }

    @Test func theHeartsSubmenu() {
        let hearts = Self.menu()[6].children
        #expect(hearts.map(\.title) == ["from the limit", "3", "2½", "2", "1½", "1", "½", "0", "", "Play losing hearts"])
        #expect(hearts.map(\.action) == [
            .hearts(nil), .hearts(6), .hearts(5), .hearts(4), .hearts(3), .hearts(2), .hearts(1), .hearts(0), nil, .drain,
        ])
        #expect(hearts[8].isSeparator)
    }

    @Test func theSkySubmenuIsEnabledOnlyWhileTheSkyShows() {
        let sky = Self.menu()[7]
        #expect(sky.enabled)
        #expect(sky.children.map(\.title) == [
            "by the clock", "dawn", "day", "dusk", "night", "", "live weather",
            "clear", "partly cloudy", "overcast", "fog", "drizzle", "rain", "rain showers", "thunderstorm", "snow",
        ])
        #expect(sky.children.map(\.action) == [
            .skyPhase(nil), .skyPhase(.dawn), .skyPhase(.day), .skyPhase(.dusk), .skyPhase(.night), nil, .skyWeather(nil),
            .skyWeather(0), .skyWeather(2), .skyWeather(3), .skyWeather(45), .skyWeather(53), .skyWeather(63),
            .skyWeather(82), .skyWeather(95), .skyWeather(73),
        ])
        #expect(!Self.menu(skyVisible: false)[7].enabled)
    }

    @Test func liveDataChecksAutoAndTheDefaults() {
        let top = Self.menu()
        #expect(Self.checked(top) == ["Auto (live data)"])
        #expect(Self.checked(top[3].children).isEmpty)
        #expect(Self.checked(top[6].children) == ["from the limit"])
        #expect(Self.checked(top[7].children) == ["by the clock", "live weather"])
        #expect(top[5].action == .sweat(true))
    }

    @Test func overridesMoveTheCheckMarks() {
        let work = Self.menu(ClawdDevState(forcedMood: .work))
        #expect(Self.checked(work) == [])
        #expect(Self.checked(work[3].children) == ["working"])

        // While the demo runs only the demo is checked, whatever mood it forces.
        let demo = Self.menu(ClawdDevState(forcedMood: .sleep, demoRunning: true))
        #expect(Self.checked(demo) == ["Show everything in turn"])
        #expect(Self.checked(demo[3].children).isEmpty)

        let sweat = Self.menu(ClawdDevState(forceCrit: true))
        #expect(Self.checked(sweat) == ["Sweating near the limit"])
        #expect(sweat[5].action == .sweat(false))

        let hearts = Self.menu(ClawdDevState(forceHearts: 3))
        #expect(Self.checked(hearts) == [])
        #expect(Self.checked(hearts[6].children) == ["1½"])

        // A drain sets the hearts every tick, but the menu shows "from the limit".
        let drain = Self.menu(ClawdDevState(forceHearts: 5, drainRunning: true))
        #expect(Self.checked(drain[6].children) == ["from the limit"])
        #expect(Self.checked(drain) == [])

        let sky = Self.menu(sky: SkyDevState(phase: .dusk, weatherCode: 95))
        #expect(Self.checked(sky[7].children) == ["dusk", "thunderstorm"])
        // A sky override does not uncheck Auto: it only covers Clawd.
        #expect(Self.checked(sky) == ["Auto (live data)"])
        #expect(Self.checked(Self.menu(sky: SkyDevState(weatherCode: 1))[7].children) == ["by the clock"])
    }

    @Test func theEngineStateDrivesTheMenu() {
        let engine = ClawdEngine.settled()
        #expect(Self.checked(Self.menu(engine.devState)) == ["Auto (live data)"])
        engine.perform(.sweat(true))
        engine.perform(.hearts(1))
        let top = Self.menu(engine.devState)
        #expect(Self.checked(top) == ["Sweating near the limit"])
        #expect(Self.checked(top[6].children) == ["½"])
    }

    @Test func skyActionsAreTheApps() {
        let engine = ClawdEngine.settled(), reference = ClawdEngine.settled()
        engine.perform(.skyPhase(.dusk))
        engine.perform(.skyWeather(95))
        engine.perform(.skyPhase(nil))
        #expect(engine.devState == ClawdDevState())
        #expect(engine.run(40) == reference.run(40))
    }

    @Test func titlesComeFromTheGivenLanguage() {
        let de = Self.menu(lang: .de)
        #expect(de[0].title == L10n.t(.mmHead, .de))
        #expect(de[3].children.map(\.title) == Mood.allCases.map { L10n.mood($0, .de) })
        #expect(de[4].children.map(\.title) == ClawdAct.allCases.map { L10n.act($0, .de) })
        #expect(de[6].children[0].title == L10n.t(.mmByLimit, .de))
        #expect(de[7].children[1 ... 4].map(\.title) == SkyPhase.allCases.map { L10n.phase($0, .de) })
        #expect(de[7].children[7...].map(\.title) == WeatherKinds.devMenuCodes.map { WeatherKinds.name(code: $0, lang: .de) })
    }
}
