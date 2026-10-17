import AppKit
import ClawBarShared

/// mascot-menu.ps1's context menu, built on every open from `DevMenu.build` so its check marks are current.
enum DevMenuBuilder {
    static func entries(_ nodes: [DevMenuNode]) -> [MenuEntry<DevAction>] {
        nodes.map { n in
            n.isSeparator
                ? .separator
                : MenuEntry(title: n.title, checked: n.checked, enabled: n.enabled, action: n.action, children: entries(n.children))
        }
    }

    static func menu(_ nodes: [DevMenuNode], perform: @escaping (DevAction) -> Void) -> NSMenu {
        MenuBuilder.menu(entries(nodes), perform: perform)
    }

    static func dump(_ nodes: [DevMenuNode]) -> String {
        MenuEntry.dump(entries(nodes))
    }
}
