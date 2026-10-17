import Foundation
import Testing
@testable import ClawBar
import ClawBarShared

/// A temporary directory per test, removed at the end.
final class TempDir {
    let url: URL
    init() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("clawbar-app-tests-\(UUID().uuidString)", isDirectory: true)
    }
    deinit { try? FileManager.default.removeItem(at: url) }
}

@Suite struct LaunchAtLoginDecisionTests {
    @Test func registersOnlyWhatIsMissingAndNeverFightsAPendingApproval() {
        #expect(LaunchAtLogin.action(desired: true, status: .notRegistered) == .register)
        #expect(LaunchAtLogin.action(desired: true, status: .notFound) == .register)
        #expect(LaunchAtLogin.action(desired: true, status: .enabled) == .none)
        // The user still has to approve it in System Settings; registering again would not help.
        #expect(LaunchAtLogin.action(desired: true, status: .requiresApproval) == .none)
        #expect(LaunchAtLogin.action(desired: false, status: .enabled) == .unregister)
        #expect(LaunchAtLogin.action(desired: false, status: .requiresApproval) == .unregister)
        #expect(LaunchAtLogin.action(desired: false, status: .notRegistered) == .none)
        #expect(LaunchAtLogin.action(desired: false, status: .notFound) == .none)
    }

    @Test func onlyAnInstalledBundleCountsAsInstalled() {
        let home = URL(fileURLWithPath: "/Users/example")
        func installed(_ path: String, id: String? = AppInfo.bundleID) -> Bool {
            LaunchAtLogin.isInstalledApp(bundleURL: URL(fileURLWithPath: path), bundleID: id, home: home)
        }
        #expect(installed("/Users/example/Applications/ClawBar.app"))
        #expect(installed("/Applications/ClawBar.app"))
        #expect(!installed("/Users/example/Dev/clawbar/build/ClawBar.app"))
        #expect(!installed("/Users/example/Dev/clawbar/.build/release"))
        #expect(!installed("/Users/example/Applications/ClawBar.app", id: "com.example.other"))
        #expect(!installed("/Users/example/Applications/ClawBar.app", id: nil))
    }
}

final class FakeLoginItem: LoginItemService {
    var status: LoginItemStatus
    var calls: [String] = []
    var failure: Error?
    init(_ status: LoginItemStatus) { self.status = status }
    func register() throws {
        calls.append("register")
        if let failure { throw failure }
        status = .enabled
    }
    func unregister() throws {
        calls.append("unregister")
        if let failure { throw failure }
        status = .notRegistered
    }
}

@Suite struct LoginItemControllerTests {
    @Test func aRunFromOutsideAnInstalledBundleNeverTouchesTheLoginItems() {
        let fake = FakeLoginItem(.notRegistered)
        let tmp = TempDir()
        let c = LoginItemController(service: fake, installed: false, log: ErrorLog(url: tmp.url.appendingPathComponent("e.log")))
        #expect(c.reconcile(desired: true) == .none)
        #expect(fake.calls.isEmpty)
    }

    @Test func theInstalledAppFollowsTheSetting() {
        let fake = FakeLoginItem(.notRegistered)
        let tmp = TempDir()
        let c = LoginItemController(service: fake, installed: true, log: ErrorLog(url: tmp.url.appendingPathComponent("e.log")))
        #expect(c.reconcile(desired: true) == .register)
        #expect(c.reconcile(desired: true) == .none)
        #expect(c.reconcile(desired: false) == .unregister)
        #expect(fake.calls == ["register", "unregister"])
    }

    @Test func aFailureIsLoggedNotThrown() throws {
        struct Denied: Error, CustomStringConvertible { var description: String { "denied" } }
        let fake = FakeLoginItem(.notRegistered)
        fake.failure = Denied()
        let tmp = TempDir()
        let log = tmp.url.appendingPathComponent("e.log")
        let c = LoginItemController(service: fake, installed: true, log: ErrorLog(url: log))
        #expect(c.reconcile(desired: true) == .register)
        let text = try String(contentsOf: log, encoding: .utf8)
        #expect(text.contains("launch at login: register failed: denied"))
    }
}

@Suite struct InstanceLockTests {
    @Test func theFirstLaunchHoldsTheLockAndASecondCannot() throws {
        let tmp = TempDir()
        let file = tmp.url.appendingPathComponent("nested/clawbar.lock")
        let first = try #require(InstanceLock.acquire(file))
        #expect(InstanceLock.acquire(file) == nil)
        #expect(InstanceLock.isHeld(file))
        first.release()
        #expect(!InstanceLock.isHeld(file))
        let again = InstanceLock.acquire(file)
        #expect(again != nil)
        again?.release()
    }

    @Test func noLockFileMeansNobodyIsRunning() {
        let tmp = TempDir()
        let file = tmp.url.appendingPathComponent("clawbar.lock")
        #expect(!InstanceLock.isHeld(file))
        #expect(!FileManager.default.fileExists(atPath: file.path), "probing must not create the lock file")
    }
}
