import AppKit
import Foundation

let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
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
