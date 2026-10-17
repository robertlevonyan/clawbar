import Foundation

/// One child process to run.
struct ProcessSpec: Sendable, Hashable {
    enum Output: Sendable, Hashable {
        /// stdout and stderr come back in the outcome, each capped.
        case capture
        /// Both go to this file, so the child outlives us: a pipe would SIGPIPE it once we quit.
        case survivesQuit(URL)
    }

    var executable: String
    var arguments: [String]
    var environment: [String: String]
    var directory: String
    /// SIGTERM after this many seconds, then SIGKILL `killAfter` later.
    var timeout: TimeInterval = 60
    var killAfter: TimeInterval = 3
    var output: Output = .capture
    /// Per stream; the rest is drained and dropped.
    var outputCap = 1 << 20
    /// After the exit, how long to wait for EOF while a grandchild may hold the pipe.
    var drainGrace: TimeInterval = 2

    var survivesQuit: Bool {
        if case .survivesQuit = output { return true }
        return false
    }
}

struct ProcessOutcome: Sendable, Hashable {
    enum Termination: Sendable, Hashable {
        case exit(Int32)
        case signal(Int32)
    }

    var pid: Int32
    var termination: Termination
    var stdout = Data()
    var stderr = Data()
    /// The timeout fired before the child exited.
    var timedOut = false

    var exitCode: Int32? {
        if case .exit(let c) = termination { return c }
        return nil
    }

    var stdoutText: String { String(decoding: stdout, as: UTF8.self) }
    var stderrText: String { String(decoding: stderr, as: UTF8.self) }
}

enum LaunchError: Error, Sendable, Hashable {
    case notFound(String)
    case notExecutable(String)
    /// posix_spawn refused for another reason, e.g. ENOEXEC for a file that is no program.
    case failed(String, errno: Int32)

    var message: String {
        switch self {
        case .notFound(let p): "not found: \(p)"
        case .notExecutable(let p): "not executable: \(p)"
        case .failed(let p, let e): "could not start \(p): \(String(cString: strerror(e)))"
        }
    }
}

typealias ProcessResult = Result<ProcessOutcome, LaunchError>
