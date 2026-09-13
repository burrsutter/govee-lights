import AppKit
import Darwin
import Foundation

/// launchd runs a bundled LaunchAgent's BundleProgram with a *relative* argv[0]
/// ("Contents/MacOS/GoveeLoginLauncher") and cwd = "/", so argv[0] resolves to
/// "/Contents/MacOS/..." and cannot locate the enclosing .app. Ask the kernel for
/// the real executable path instead; it is always absolute.
private func currentExecutableURL() -> URL {
    var size = UInt32(0)
    _ = _NSGetExecutablePath(nil, &size)
    var buffer = [CChar](repeating: 0, count: Int(size))
    guard _NSGetExecutablePath(&buffer, &size) == 0 else {
        return URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    }
    return URL(fileURLWithPath: String(cString: buffer)).resolvingSymlinksInPath().standardizedFileURL
}

let executableURL = currentExecutableURL()
let appURL = executableURL
    .deletingLastPathComponent() // MacOS
    .deletingLastPathComponent() // Contents
    .deletingLastPathComponent() // GoveeMenuBar.app

guard appURL.pathExtension == "app" else {
    fputs("Unable to locate GoveeMenuBar.app from \(executableURL.path)\n", stderr)
    exit(EXIT_FAILURE)
}

let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false
configuration.addsToRecentItems = false

NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
    if let error {
        fputs("Unable to open GoveeMenuBar.app: \(error.localizedDescription)\n", stderr)
        exit(EXIT_FAILURE)
    }
    exit(EXIT_SUCCESS)
}

RunLoop.main.run()
