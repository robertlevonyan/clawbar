import Foundation

/// Scrubs personal data from anything ClawBar writes or prints: logs, diagnostics, snapshots.
public enum Redact {
    /// The home directory becomes `~`; e-mail addresses, IPv4 addresses and Anthropic keys become placeholders.
    public static func text(_ s: String, home: String = NSHomeDirectory()) -> String {
        var out = s
        if home.count > 1 {
            let trimmed = home.hasSuffix("/") ? String(home.dropLast()) : home
            out = out.replacingOccurrences(of: trimmed, with: "~")
        }
        out = Rx.replace(secretPattern, in: out, with: "<secret>")
        out = Rx.replace(emailPattern, in: out, with: "<email>")
        out = Rx.replace(ipv4Pattern, in: out, with: "<ip>")
        return out
    }

    /// `user@example.com` → `u…@example.com`, for showing an account without printing it.
    public static func email(_ s: String) -> String {
        guard let at = s.firstIndex(of: "@"), at > s.startIndex else { return s.isEmpty ? s : "<email>" }
        return "\(s[s.startIndex])…\(s[at...])"
    }

    private static let secretPattern = Rx.make("sk-ant-[A-Za-z0-9_\\-]+")
    private static let emailPattern = Rx.make("[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}")
    private static let ipv4Pattern = Rx.make("(?<![0-9.])(?:[0-9]{1,3}\\.){3}[0-9]{1,3}(?![0-9.])")
}
