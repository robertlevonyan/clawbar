import Foundation
import ClawBarShared

/// format.ps1 Format-Span: the time left until a reset.
public enum Span {
    /// `4d 15h` from a day, `2h 05m` from an hour, else `35m`; nil at or below zero.
    public static func text(until end: Date, now: Date, lang: Lang) -> String? {
        let seconds = end.timeIntervalSince(now)
        guard seconds > 0 else { return nil }
        // TimeSpan components truncate; the original floors TotalHours on purpose, so 4:59:59 is 4h 59m.
        let totalHours = seconds / 3600
        let minutes = Int(seconds / 60) % 60
        if totalHours >= 24 { return L10n.t(.spanD, lang, Int(seconds / 86_400), Int(totalHours) % 24) }
        if totalHours >= 1 { return L10n.t(.spanH, lang, Int(totalHours), minutes) }
        return L10n.t(.spanM, lang, minutes)
    }
}
