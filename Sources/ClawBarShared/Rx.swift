import Foundation

/// A thin wrapper over NSRegularExpression: patterns are built once as statics, matches come back as strings.
public enum Rx {
    public struct Match {
        fileprivate let groups: [String?]

        /// Group `i`, nil when it did not take part.
        public subscript(_ i: Int) -> String? { i < groups.count ? groups[i] : nil }

        /// The groups, the whole match (group 0) included.
        public var count: Int { groups.count }
    }

    public static func make(_ pattern: String) -> NSRegularExpression {
        // A bad literal pattern is a programming error caught by the first test that touches it.
        try! NSRegularExpression(pattern: pattern)
    }

    public static func first(_ re: NSRegularExpression, in s: String) -> Match? {
        re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)).map { match($0, s) }
    }

    public static func all(_ re: NSRegularExpression, in s: String) -> [Match] {
        re.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { match($0, s) }
    }

    public static func replace(_ re: NSRegularExpression, in s: String, with template: String) -> String {
        re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }

    public static func matches(_ re: NSRegularExpression, _ s: String) -> Bool { first(re, in: s) != nil }

    private static func match(_ m: NSTextCheckingResult, _ s: String) -> Match {
        Match(groups: (0 ..< m.numberOfRanges).map { i in
            Range(m.range(at: i), in: s).map { String(s[$0]) }
        })
    }
}
