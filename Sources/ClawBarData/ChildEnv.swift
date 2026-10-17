import Foundation

/// What the login shell knows that a GUI app does not.
struct LoginEnvironment: Sendable, Hashable {
    /// `command -v claude`, when it printed an absolute path.
    var claudePath: String?
    var path: String?
    var claudeConfigDir: String?

    init(claudePath: String? = nil, path: String? = nil, claudeConfigDir: String? = nil) {
        self.claudePath = claudePath
        self.path = path
        self.claudeConfigDir = claudeConfigDir
    }
}

/// The environment every child gets: ours minus what Claude Code sets for its own children, with a PATH that
/// finds claude, node and the system tools claude calls by bare name (`security`, `ps`).
enum ChildEnv {
    /// Set by a running Claude Code for its children; inherited when ClawBar starts from one of its shells.
    static let scrubbedNames: Set<String> = [
        "CLAUDECODE",
        "CLAUDE_CODE_ENTRYPOINT",
        "CLAUDE_CODE_EXECPATH",
        "CLAUDE_CODE_CHILD_SESSION",
        "CLAUDE_CODE_SESSION_ID",
        "CLAUDE_CODE_SESSION_ATTENDED",
        "CLAUDE_CODE_MESSAGING_SOCKET",
        "CLAUDE_CODE_MESSAGING_TOKEN",
        "CLAUDE_CODE_SSE_PORT",
        "CLAUDE_PID",
        "CLAUDE_EFFORT",
        "CLAUDE_PROJECT_DIR",
        "CLAUDE_ENV_FILE",
        "CLAUDE_AGENT_SDK_VERSION",
        "AI_AGENT",
    ]

    /// Whole families of per-session variables, including ones newer CLIs add.
    static let scrubbedPrefixes = ["CLAUDE_CODE_SESSION_", "CLAUDE_CODE_MESSAGING_"]

    static let brewDirectories = ["/opt/homebrew/bin", "/usr/local/bin"]
    static let systemDirectories = ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]

    static func scrub(_ env: [String: String]) -> [String: String] {
        env.filter { key, _ in
            !scrubbedNames.contains(key) && !scrubbedPrefixes.contains { key.hasPrefix($0) }
        }
    }

    static func make(inherited: [String: String], login: LoginEnvironment?, claude: String?) -> [String: String] {
        var env = scrub(inherited)
        let claudeDir = claude.map { ($0 as NSString).deletingLastPathComponent }
        env["PATH"] = path(base: login?.path ?? inherited["PATH"], claudeDirectory: claudeDir)
        if let dir = login?.claudeConfigDir, !dir.isEmpty { env["CLAUDE_CONFIG_DIR"] = dir }
        return env
    }

    /// The base, then claude's folder, Homebrew and the system folders; each folder once, first place wins.
    static func path(base: String?, claudeDirectory: String?) -> String {
        var seen = Set<String>()
        var out: [String] = []
        let parts = (base ?? "").split(separator: ":").map(String.init)
            + [claudeDirectory].compactMap { $0 } + brewDirectories + systemDirectories
        for p in parts where !p.isEmpty && seen.insert(p).inserted { out.append(p) }
        return out.joined(separator: ":")
    }
}
