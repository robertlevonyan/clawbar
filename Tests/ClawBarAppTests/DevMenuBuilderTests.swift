import AppKit
import Testing
@testable import ClawBar
import ClawBarShared

@MainActor
@Suite struct DevMenuBuilderTests {
    /// A tree shaped like mascot-menu.ps1's: header, Auto, a submenu, a checkable item, a disabled submenu.
    let nodes: [DevMenuNode] = [
        DevMenuNode(title: "Developer mode", enabled: false),
        .separator,
        DevMenuNode(title: "Auto (live data)", checked: true, action: .auto),
        DevMenuNode(title: "State", children: [
            DevMenuNode(title: "sleeping", action: .mood(.sleep)),
            DevMenuNode(title: "working", checked: true, action: .mood(.work)),
        ]),
        DevMenuNode(title: "Sweating near the limit", action: .sweat(true)),
        DevMenuNode(title: "Sky", enabled: false, children: [
            DevMenuNode(title: "by the clock", checked: true, action: .skyPhase(nil)),
            .separator,
            DevMenuNode(title: "night", action: .skyPhase(.night)),
        ]),
    ]

    @Test func theTreeBecomesAnNSMenuWithItsChecksAndDisabledItems() throws {
        let menu = DevMenuBuilder.menu(nodes) { _ in }
        #expect(!menu.autoenablesItems)
        #expect(menu.items.map { $0.isSeparatorItem ? "---" : $0.title } == [
            "Developer mode", "---", "Auto (live data)", "State", "Sweating near the limit", "Sky",
        ])
        #expect(!menu.items[0].isEnabled)
        #expect(menu.items[2].state == .on)
        #expect(menu.items[4].state == .off)
        let state = try #require(menu.items[3].submenu)
        #expect(state.items.map(\.state) == [.off, .on])
        // The Sky submenu is disabled while the sky is hidden.
        #expect(!menu.items[5].isEnabled)
        let sky = try #require(menu.items[5].submenu)
        #expect(sky.items[1].isSeparatorItem)
    }

    @Test func clicksHandBackTheNodesAction() throws {
        var got: [DevAction] = []
        let menu = DevMenuBuilder.menu(nodes) { got.append($0) }
        click(menu.items[2])
        click(try #require(menu.items[3].submenu).items[1])
        click(menu.items[4])
        click(try #require(menu.items[5].submenu).items[2])
        #expect(got == [.auto, .mood(.work), .sweat(true), .skyPhase(.night)])
    }

    @Test func theDumpListsEveryLevel() {
        let dump = DevMenuBuilder.dump(nodes)
        #expect(dump.contains("Developer mode  (disabled)"))
        #expect(dump.contains("[x] Auto (live data)"))
        #expect(dump.contains("State ▸"))
        #expect(dump.contains("    [x] working"))
        #expect(dump.contains("Sky ▸  (disabled)"))
    }
}
