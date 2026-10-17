import Foundation
import ClawBarShared

/// mascot-menu.ps1's developer menu as a tree, check marks included.
public enum DevMenu {
    /// The menu as it looks when it opens: check marks from the current overrides, Sky enabled only while it shows.
    public static func build(dev: ClawdDevState, sky: SkyDevState, skyVisible: Bool, lang: Lang) -> [DevMenuNode] {
        let states = Mood.allCases.map { m in
            DevMenuNode(title: L10n.mood(m, lang), checked: !dev.demoRunning && dev.forcedMood == m, action: .mood(m))
        }
        let acts = ClawdAct.allCases.map { DevMenuNode(title: L10n.act($0, lang), action: .act($0)) }

        // A drain sets the hearts every tick; the menu still shows "from the limit" then.
        let shownHearts = dev.drainRunning ? nil : dev.forceHearts
        var hearts = [DevMenuNode(title: L10n.t(.mmByLimit, lang), checked: shownHearts == nil, action: .hearts(nil))]
        hearts += ClawdTables.devMenuHearts.map {
            DevMenuNode(title: $0.label, checked: shownHearts == $0.halves, action: .hearts($0.halves))
        }
        hearts += [.separator, DevMenuNode(title: L10n.t(.mmDrain, lang), action: .drain)]

        var skyItems = [DevMenuNode(title: L10n.t(.mmByClock, lang), checked: sky.phase == nil, action: .skyPhase(nil))]
        skyItems += SkyPhase.allCases.map {
            DevMenuNode(title: L10n.phase($0, lang), checked: sky.phase == $0, action: .skyPhase($0))
        }
        skyItems.append(.separator)
        skyItems.append(DevMenuNode(title: L10n.t(.mmWxLive, lang), checked: sky.weatherCode == nil, action: .skyWeather(nil)))
        skyItems += WeatherKinds.devMenuCodes.map {
            DevMenuNode(title: WeatherKinds.name(code: $0, lang: lang), checked: sky.weatherCode == $0, action: .skyWeather($0))
        }

        return [
            DevMenuNode(title: L10n.t(.mmHead, lang), enabled: false),
            .separator,
            DevMenuNode(title: L10n.t(.mmAuto, lang), checked: dev.isAuto, action: .auto),
            DevMenuNode(title: L10n.t(.mmState, lang), children: states),
            DevMenuNode(title: L10n.t(.mmAnim, lang), children: acts),
            // A checkable item: the click carries the new state.
            DevMenuNode(title: L10n.t(.mmSweat, lang), checked: dev.forceCrit, action: .sweat(!dev.forceCrit)),
            DevMenuNode(title: L10n.t(.mmHearts, lang), children: hearts),
            DevMenuNode(title: L10n.t(.mmSky, lang), enabled: skyVisible, children: skyItems),
            .separator,
            DevMenuNode(title: L10n.t(.mmDemo, lang), checked: dev.demoRunning, action: .demo),
        ]
    }
}
