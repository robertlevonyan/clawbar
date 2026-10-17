import Foundation
import Testing
import ClawBarPresenter
import ClawBarShared

@Suite struct StatLineTests {
    /// Every indented line of the data layer's real /usage fixtures, as the parser hands them over: trimmed.
    private static func fixtureLines(_ name: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ClawBarDataTests/Fixtures/usage/\(name)")
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: true)
            .filter { $0.first == " " || $0.first == "\t" }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// The original's 7 rules plus every line Claude Code 2.1.302 can print, in English.
    private static let english: [String: String] = [
        // today.txt, Last 24h
        "89% of your usage came from subagent-heavy sessions": "89% subagent-heavy sessions",
        "84% of your usage was at >150k context": "84% at >150k context",
        "78% of your usage was at max effort": "78% at max effort",
        "65% of your usage came from workflows": "65% from workflows",
        "50% of your usage came from sessions active for 8+ hours": "50% sessions 8h+",
        "15% of your usage was while 4+ sessions ran in parallel": "15% with 4+ sessions in parallel",
        "12% of your usage went to tool results over 10k tokens": "12% tool results >10k",
        "Top skills: /notes 2%": "skills: /notes 2%",
        "Top subagents: helper 47%, tracker:sync 9%, builder 6%, writer 5%, planner 4%, forker 2%, scout 1%":
            "subagents: helper 47%, tracker:sync 9%, builder 6%, writer 5%, planner 4%, forker 2%, scout 1%",
        "Top plugins: tracker 10%": "plugins: tracker 10%",
        "Top MCP servers: docs-server 1%": "MCP: docs-server 1%",
        // today.txt, Last 7d
        "82% of your usage came from subagent-heavy sessions": "82% subagent-heavy sessions",
        "70% of your usage was at >150k context": "70% at >150k context",
        "59% of your usage was at max effort": "59% at max effort",
        "49% of your usage came from workflows": "49% from workflows",
        "37% of your usage came from sessions active for 8+ hours": "37% sessions 8h+",
        "14% of your usage was while 4+ sessions ran in parallel": "14% with 4+ sessions in parallel",
        "11% of your usage went to always-on context over 40k tokens": "11% always-on context >40k",
        "10% of your usage went to tool results over 10k tokens": "10% tool results >10k",
        "Top skills: /notes 2%, /tracker:sync 1%, /style 1%": "skills: /notes 2%, /tracker:sync 1%, /style 1%",
        "Top subagents: helper 35%, tracker:sync 7%, builder 6%, writer 3%, planner 3%, tidy 2%, forker 2%, reviewer 1%, +1 more":
            "subagents: helper 35%, tracker:sync 7%, builder 6%, writer 3%, planner 3%, tidy 2%, forker 2%, reviewer 1%, +1 more",
        "Top plugins: tracker 8%, release-kit 1%": "plugins: tracker 8%, release-kit 1%",
        // all-lines.txt
        "61% of your usage hit a >100k-token cache miss": "61% >100k-token cache misses",
        "52% of your usage was at >150k context": "52% at >150k context",
        "48% of your usage came from subagent-heavy sessions": "48% subagent-heavy sessions",
        "33% of your usage was while 4+ sessions ran in parallel": "33% with 4+ sessions in parallel",
        "27% of your usage came from sessions active for 8+ hours": "27% sessions 8h+",
        "21% of your usage was at max effort": "21% at max effort",
        "14% of your usage came from workflows": "14% from workflows",
        "9% of your usage went to always-on context over 40k tokens": "9% always-on context >40k",
        "5% of your usage went to tool results over 10k tokens": "5% tool results >10k",
        "Top skills: /notes 2%, /style 1%": "skills: /notes 2%, /style 1%",
        "Top subagents: helper 35%, reviewer 7%, +3 more": "subagents: helper 35%, reviewer 7%, +3 more",
        "Top plugins: tracker 8%, release-kit 1%, +1 more": "plugins: tracker 8%, release-kit 1%, +1 more",
        "A brand new kind of line nobody has seen yet": "A brand new kind of line nobody has seen yet",
    ]

    @Test(arguments: ["today.txt", "all-lines.txt"])
    func everyFixtureLineHasItsEnglishRendering(fixture: String) throws {
        let lines = try Self.fixtureLines(fixture)
        #expect(lines.count >= 14)
        for line in lines {
            let expected = try #require(Self.english[line], "no expectation for \"\(line)\"")
            #expect(StatLine.text(line, lang: .en) == expected)
        }
    }

    /// One line per rule from all-lines.txt, in German.
    @Test func everyRuleHasItsGermanRendering() {
        let german: [String: String] = [
            "61% of your usage hit a >100k-token cache miss": "61% Cache-Misses >100k Tokens",
            "52% of your usage was at >150k context": "52% bei Kontext >150k",
            "48% of your usage came from subagent-heavy sessions": "48% Subagent-lastige Sitzungen",
            "33% of your usage was while 4+ sessions ran in parallel": "33% bei 4+ parallelen Sitzungen",
            "27% of your usage came from sessions active for 8+ hours": "27% Sitzungen ab 8h",
            "21% of your usage was at max effort": "21% bei maximalem Aufwand",
            "14% of your usage came from workflows": "14% aus Workflows",
            "9% of your usage went to always-on context over 40k tokens": "9% Dauerkontext >40k",
            "5% of your usage went to tool results over 10k tokens": "5% Tool-Ergebnisse >10k",
            "Top skills: /notes 2%, /style 1%": "Skills: /notes 2%, /style 1%",
            "Top subagents: helper 35%, reviewer 7%, +3 more": "Subagents: helper 35%, reviewer 7%, +3 weitere",
            "Top plugins: tracker 8%, release-kit 1%, +1 more": "Plugins: tracker 8%, release-kit 1%, +1 weitere",
            "Top MCP servers: docs-server 1%": "MCP: docs-server 1%",
            "A brand new kind of line nobody has seen yet": "A brand new kind of line nobody has seen yet",
        ]
        for (line, expected) in german {
            #expect(StatLine.text(line, lang: .de) == expected)
        }
    }

    @Test func thresholdsAreCapturedNotHardCoded() {
        #expect(StatLine.text("45% of your usage was at >200k context", lang: .en) == "45% at >200k context")
        #expect(StatLine.text("61% of your usage hit a >250k-token cache miss", lang: .en) == "61% >250k-token cache misses")
        #expect(StatLine.text("33% of your usage was while 6+ sessions ran in parallel", lang: .en) == "33% with 6+ sessions in parallel")
        #expect(StatLine.text("27% of your usage came from sessions active for 12+ hours", lang: .en) == "27% sessions 12h+")
        #expect(StatLine.text("9% of your usage went to always-on context over 60k tokens", lang: .en) == "9% always-on context >60k")
        #expect(StatLine.text("5% of your usage went to tool results over 25k tokens", lang: .en) == "5% tool results >25k")
    }

    @Test func unknownLinesAndListsStayRaw() {
        #expect(StatLine.text("Top hooks: lint 4%", lang: .de) == "Top hooks: lint 4%")
        #expect(StatLine.text("top skills: /notes 2%", lang: .en) == "top skills: /notes 2%")
        #expect(StatLine.text("", lang: .en) == "")
    }

    @Test func onlyATrailingMoreIsTranslated() {
        // A name that merely contains "more" keeps it.
        #expect(StatLine.text("Top plugins: more-tools 3%, +12 more", lang: .de) == "Plugins: more-tools 3%, +12 weitere")
        #expect(StatLine.text("Top skills: /more 2%", lang: .de) == "Skills: /more 2%")
    }
}
