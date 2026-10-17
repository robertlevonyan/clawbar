import Foundation
import ClawBarShared

/// status.claude.com's Statuspage summary.
enum StatusProbe {
    static func parse(_ data: Data) -> ServiceStatus? {
        guard let j = JSONFile.object(from: data) else { return nil }
        var broken: [BrokenComponent] = []
        for c in j["components"] as? [[String: Any]] ?? [] {
            let state = Lenient.string(c["status"]) ?? ""
            guard Lenient.bool(c["group"]) != true, state.lowercased() != "operational" else { continue }
            let name = Rx.replace(parenthetical, in: Lenient.string(c["name"]) ?? "", with: "")
            broken.append(BrokenComponent(name: name, state: state))
        }
        let incidents = (j["incidents"] as? [[String: Any]] ?? []).compactMap { Lenient.string($0["name"]) }
        let indicator = Lenient.string((j["status"] as? [String: Any])?["indicator"]) ?? ""
        return ServiceStatus(indicator: indicator, incidents: incidents, broken: broken)
    }

    /// "Claude API (api.anthropic.com)" → "Claude API".
    private static let parenthetical = Rx.make(#"\s*\(.*\)\s*$"#)
}
