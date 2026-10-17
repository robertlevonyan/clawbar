import Foundation

/// Finds the claude executable without a shell PATH: a GUI app gets launchd's minimal one.
struct ClaudeLocator: Sendable {
    enum Source: String, Sendable, Hashable {
        case config, candidate, loginShell, loginPath
    }

    struct Found: Sendable, Hashable {
        /// As found, symlinks kept: auto-update re-points `~/.local/bin/claude` at each new version.
        var path: String
        var source: Source
    }

    let home: String
    let candidates: [String]

    init(home: String, candidates: [String]? = nil) {
        self.home = home
        self.candidates = candidates ?? Self.candidates(home: home)
    }

    /// The native installer, the old local install, Homebrew (Apple silicon, Intel) and common npm global bins.
    static func candidates(home: String) -> [String] {
        [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.npm-global/bin/claude",
            "\(home)/.volta/bin/claude",
            "\(home)/.bun/bin/claude",
            "\(home)/Library/pnpm/claude",
            "\(home)/.local/share/pnpm/claude",
        ]
    }

    /// `claudePath`, the candidates, the login shell's `command -v claude`, then its PATH.
    func locate(configPath: String?, login: LoginEnvironment?) -> Found? {
        if let p = configPath.map(expand), !p.isEmpty, Self.runnable(p) { return Found(path: p, source: .config) }
        if let c = candidates.first(where: Self.runnable) { return Found(path: c, source: .candidate) }
        if let p = login?.claudePath, p.hasPrefix("/"), Self.runnable(p) { return Found(path: p, source: .loginShell) }
        for dir in (login?.path ?? "").split(separator: ":") where dir.hasPrefix("/") {
            let p = "\(dir)/claude"
            if Self.runnable(p) { return Found(path: p, source: .loginPath) }
        }
        return nil
    }

    private func expand(_ p: String) -> String {
        expandingTilde(p.trimmingCharacters(in: .whitespacesAndNewlines), home: home)
    }

    private static func runnable(_ p: String) -> Bool { ProcessRunner.check(p) == nil }
}

/// One run of the user's login shell for what their profile sets up: claude's path, PATH and CLAUDE_CONFIG_DIR.
enum LoginShell {
    /// Shell-neutral (zsh, bash, fish): echo, `command -v` and /usr/bin/printenv between sentinels.
    static let script = [
        "echo __CLAWBAR_CLAUDE__", "command -v claude",
        "echo __CLAWBAR_PATH__", "/usr/bin/printenv PATH",
        "echo __CLAWBAR_CONFIG__", "/usr/bin/printenv CLAUDE_CONFIG_DIR",
        "echo __CLAWBAR_END__",
    ].joined(separator: "; ")

    static func spec(shell: String, environment: [String: String], home: String, timeout: TimeInterval = 5) -> ProcessSpec {
        ProcessSpec(
            executable: shell, arguments: ["-ilc", script], environment: environment, directory: home,
            timeout: timeout, killAfter: 1, drainGrace: 0.5
        )
    }

    /// `$SHELL`, else the account's shell, else zsh.
    static func shell(environment: [String: String]) -> String {
        if let s = environment["SHELL"], s.hasPrefix("/") { return s }
        if let pw = getpwuid(getuid()), let sh = pw.pointee.pw_shell {
            let s = String(cString: sh)
            if s.hasPrefix("/") { return s }
        }
        return "/bin/zsh"
    }

    static func capture(
        runner: any ProcessRunning, shell: String, environment: [String: String], home: String, timeout: TimeInterval = 5
    ) async -> LoginEnvironment? {
        let env = ChildEnv.make(inherited: environment, login: nil, claude: nil)
        guard case .success(let o) = await runner.run(spec(shell: shell, environment: env, home: home, timeout: timeout)),
              !o.timedOut
        else { return nil }
        return parse(o.stdoutText, home: home)
    }

    /// nil when the script never started; sections cut off by a crash or timeout stay nil.
    static func parse(_ output: String, home: String) -> LoginEnvironment? {
        let lines = output.replacingOccurrences(of: "\r", with: "").split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let start = lines.firstIndex(of: "__CLAWBAR_CLAUDE__") else { return nil }
        func section(_ from: String, _ to: String) -> [String]? {
            guard let a = lines[start...].firstIndex(of: from), let b = lines[a...].firstIndex(of: to) else { return nil }
            return Array(lines[(a + 1) ..< b])
        }
        var env = LoginEnvironment()
        env.claudePath = section("__CLAWBAR_CLAUDE__", "__CLAWBAR_PATH__")?.first { $0.hasPrefix("/") }
        env.path = section("__CLAWBAR_PATH__", "__CLAWBAR_CONFIG__")?.first { !$0.isEmpty }
        if let dir = section("__CLAWBAR_CONFIG__", "__CLAWBAR_END__")?.first(where: { !$0.isEmpty }) {
            env.claudeConfigDir = expandingTilde(dir, home: home)
        }
        return env
    }
}
