/// What `ClawBar --diagnose` found: one redacted line per finding.
public struct DiagnosticsReport: Sendable, Hashable {
    public var lines: [String]

    public init(lines: [String]) { self.lines = lines }

    public var text: String { lines.joined(separator: "\n") }
}
