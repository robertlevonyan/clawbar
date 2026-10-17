import Foundation
import ClawBarShared

/// usage.ps1 Format-StatLine, extended to every behaviour and Top list Claude Code 2.1.302 prints.
public enum StatLine {
    private struct Rule: Sendable {
        let pattern: NSRegularExpression
        let key: L10nKey
        /// A Top list, whose trailing `, +N more` is translated.
        let isList: Bool
    }

    private static func rule(_ pattern: String, _ key: L10nKey, list: Bool = false) -> Rule {
        Rule(pattern: Rx.make(pattern), key: key, isList: list)
    }

    // The original's rules first. Case-sensitive like [regex]::Match; thresholds are captured, never assumed.
    private static let rules: [Rule] = [
        rule(#"^(\d+)% of your usage was at >(\S+) context"#, .statBigCtx),
        rule(#"^(\d+)% of your usage went to always-on context over (\S+)"#, .statAlwaysOn),
        rule(#"^(\d+)% of your usage came from subagent-heavy"#, .statSubagents),
        rule(#"^(\d+)% of your usage came from sessions active for (\d+)\+? hours"#, .statLong),
        rule(#"^Top MCP servers:\s*(.+)$"#, .statMcp, list: true),
        rule(#"^Top skills:\s*(.+)$"#, .statSkills, list: true),
        rule(#"^Top subagents:\s*(.+)$"#, .statAgents, list: true),
        rule(#"^(\d+)% of your usage hit an? >(\S+)-token cache miss"#, .statCacheMiss),
        rule(#"^(\d+)% of your usage was while (\d+)\+? sessions ran in parallel"#, .statParallel),
        rule(#"^(\d+)% of your usage was at max effort"#, .statMaxEffort),
        rule(#"^(\d+)% of your usage came from workflows"#, .statWorkflows),
        rule(#"^(\d+)% of your usage went to tool results over (\S+)"#, .statToolResults),
        rule(#"^Top plugins:\s*(.+)$"#, .statPlugins, list: true),
    ]

    private static let more = Rx.make(#"^(.*), \+(\d+) more$"#)

    /// The translated line, or the line unchanged when no rule knows it, so new metrics still show.
    public static func text(_ raw: String, lang: Lang) -> String {
        for rule in rules {
            guard let m = Rx.first(rule.pattern, in: raw) else { continue }
            var args = (1 ..< m.count).map { m[$0] ?? "" }
            if rule.isList, let list = args.last { args[args.count - 1] = translatingMore(list, lang) }
            return L10n.format(L10n.t(rule.key, lang), args)
        }
        return raw
    }

    /// Names and percentages stay as Claude Code wrote them; only the trailing count is translated.
    private static func translatingMore(_ list: String, _ lang: Lang) -> String {
        guard let m = Rx.first(more, in: list), let n = Int(m[2] ?? "") else { return list }
        return (m[1] ?? "") + ", " + L10n.t(.statMore, lang, n)
    }
}
