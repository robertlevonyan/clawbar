import Foundation
import ClawBarShared

/// `~` and `~/…` against `home`; any other path unchanged.
func expandingTilde(_ path: String, home: String) -> String {
    if path == "~" { return home }
    return path.hasPrefix("~/") ? home + path.dropFirst() : path
}

/// Where Claude Code keeps its settings and session registry.
enum ClaudeConfigDir {
    /// The auth probe's, else the login shell's, else our own CLAUDE_CONFIG_DIR, else ~/.claude.
    static func resolve(account: AccountInfo?, login: LoginEnvironment?, environment: [String: String], home: String) -> String {
        if let d = account?.configDirectory, !d.isEmpty { return expandingTilde(d, home: home) }
        if let d = login?.claudeConfigDir, !d.isEmpty { return expandingTilde(d, home: home) }
        if let d = environment["CLAUDE_CONFIG_DIR"], !d.isEmpty { return expandingTilde(d, home: home) }
        return home + "/.claude"
    }
}
