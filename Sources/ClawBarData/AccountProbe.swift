import Foundation
import ClawBarShared

/// `claude auth status`: JSON on stdout, exit 1 when logged out.
enum AccountProbe {
    static let planNames = ["max": "Max", "pro": "Pro", "team": "Team", "enterprise": "Enterprise", "free": "Free"]

    static func spec(claude: String, environment: [String: String], home: String) -> ProcessSpec {
        ProcessSpec(executable: claude, arguments: ["auth", "status"], environment: environment, directory: home, timeout: 60)
    }

    /// The account whatever the exit code; nil (keep the last one) when nothing readable came back.
    static func interpret(_ result: ProcessResult) -> AccountInfo? {
        guard case .success(let o) = result, !o.timedOut else { return nil }
        return parse(o.stdout)
    }

    static func parse(_ data: Data) -> AccountInfo? {
        guard let j = JSONFile.object(from: data) else { return nil }
        let sub = Lenient.string(j["subscriptionType"]) ?? ""
        let method = Lenient.string(j["authMethod"]) ?? ""
        let plan: String
        if let named = planNames[sub.lowercased()] {
            plan = named
        } else if sub.isEmpty, !method.isEmpty, method.lowercased() != "claude.ai" {
            plan = "API"
        } else {
            plan = sub
        }
        let dir = Lenient.string(j["configDirectory"]).flatMap { $0.isEmpty ? nil : $0 }
        return AccountInfo(
            loggedIn: Lenient.bool(j["loggedIn"]) ?? false, plan: plan, email: Lenient.string(j["email"]) ?? "",
            configDirectory: dir
        )
    }
}
