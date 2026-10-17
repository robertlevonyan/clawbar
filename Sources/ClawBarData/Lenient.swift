import Foundation
import ClawBarShared

/// JSONSerialization values read the forgiving way PowerShell did: "false" is false, "12" is 12.
enum Lenient {
    static func isBool(_ v: Any?) -> Bool {
        guard let n = v as? NSNumber else { return false }
        return CFGetTypeID(n) == CFBooleanGetTypeID()
    }

    static func bool(_ v: Any?) -> Bool? {
        switch v {
        case let n as NSNumber:
            return isBool(n) ? n.boolValue : (n.doubleValue.isFinite ? n.doubleValue != 0 : nil)
        case let s as String:
            switch s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes", "on": return true
            case "false", "0", "no", "off", "": return false
            default: return nil
            }
        default:
            return nil
        }
    }

    static func double(_ v: Any?) -> Double? {
        switch v {
        case let n as NSNumber where !isBool(n):
            return n.doubleValue.isFinite ? n.doubleValue : nil
        case let s as String:
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let d = Double(t), d.isFinite else { return nil }
            return d
        default:
            return nil
        }
    }

    /// Whole numbers; halves round to even like PowerShell's [int].
    static func int(_ v: Any?) -> Int? {
        guard let d = double(v), abs(d) < 1e15 else { return nil }
        return Int(d.rounded(.toNearestOrEven))
    }

    static func string(_ v: Any?) -> String? {
        switch v {
        case let s as String: return s
        case let n as NSNumber where !isBool(n): return n.stringValue
        default: return nil
        }
    }
}
