import Foundation
import ClawBarShared

/// Probe cadence: due when the interval has passed since the last attempt.
enum Cadence {
    /// A clock set back past the last attempt counts as due, so probes never stall.
    static func due(last: Date?, interval: TimeInterval, now: Date) -> Bool {
        guard let last else { return true }
        let elapsed = now.timeIntervalSince(last)
        return elapsed < 0 || elapsed >= interval
    }
}
