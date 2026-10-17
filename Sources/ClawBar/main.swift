import Foundation

// CLI modes are decided before the single-instance lock, so they work next to a running app.
switch CLI.parse(Array(CommandLine.arguments.dropFirst())) {
case .failure(let e):
    FileHandle.standardError.write(Data("ClawBar: \(e.message)\n\(CLI.usage)\n".utf8))
    exit(2)
case .success(let mode):
    exit(CLIRunner.run(mode))
}
