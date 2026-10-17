import AppKit
import ClawBarShared

/// Talks to the running instance through distributed notifications: "show" from a second launch,
/// `--command`, and `--dump-state`. Delivered immediately, because an accessory app is never active.
enum IPC {
    static let show = Notification.Name("dev.vr1e.clawbar.show")
    static let command = Notification.Name("dev.vr1e.clawbar.command")
    static let dumpState = Notification.Name("dev.vr1e.clawbar.dump-state")
    static let commandKey = "command"
    static let nonceKey = "nonce"

    static func post(_ name: Notification.Name, userInfo: [String: String]? = nil) {
        DistributedNotificationCenter.default().postNotificationName(
            name, object: AppInfo.bundleID, userInfo: userInfo, deliverImmediately: true
        )
    }

    static func send(_ c: RemoteCommand) {
        post(command, userInfo: [commandKey: c.wire])
    }

    /// The running instance writes its dump here, never to a path a notification names.
    static func dumpFile(_ paths: AppPaths) -> URL {
        paths.root.appendingPathComponent("state-dump.txt")
    }
}

/// Receives the notifications on the main thread and hands them to the app.
final class IPCListener: NSObject {
    var onShow: () -> Void = {}
    var onCommand: (RemoteCommand) -> Void = { _ in }
    var onDumpState: (String) -> Void = { _ in }

    func start() {
        let center = DistributedNotificationCenter.default()
        for (name, selector) in [
            (IPC.show, #selector(show(_:))), (IPC.command, #selector(command(_:))), (IPC.dumpState, #selector(dump(_:))),
        ] {
            center.addObserver(self, selector: selector, name: name, object: AppInfo.bundleID, suspensionBehavior: .deliverImmediately)
        }
    }

    func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func show(_ n: Notification) { onShow() }

    @objc private func command(_ n: Notification) {
        guard let wire = n.userInfo?[IPC.commandKey] as? String, let c = RemoteCommand(wire: wire) else { return }
        onCommand(c)
    }

    @objc private func dump(_ n: Notification) {
        onDumpState(n.userInfo?[IPC.nonceKey] as? String ?? "")
    }
}
