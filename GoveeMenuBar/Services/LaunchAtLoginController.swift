import Foundation
import OSLog
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    private static let agentPlistName = "com.burrsutter.GoveeMenuBar.login.plist"
    private let logger = Logger(subsystem: "com.burrsutter.GoveeMenuBar", category: "LaunchAtLogin")

    private var service: SMAppService {
        SMAppService.agent(plistName: Self.agentPlistName)
    }

    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var lastError: String?

    init() {
        refresh()
        if CommandLine.arguments.contains("--enable-launch-at-login") {
            Task { @MainActor [weak self] in
                await self?.enableIfRequested()
            }
        }
    }

    func enableIfRequested() async {
        guard CommandLine.arguments.contains("--enable-launch-at-login") else { return }

        // Re-register an existing agent after an app update so launchd sees the
        // newly signed launcher and plist from the installed bundle.
        if service.status == .enabled {
            do {
                try await service.unregister()
                try? await Task.sleep(for: .milliseconds(300))
            } catch {
                logger.error("Login Item refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        setEnabled(true)
    }

    func refresh() {
        let status = service.status
        isEnabled = status == .enabled || status == .requiresApproval
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil

        do {
            if enabled {
                switch service.status {
                case .notRegistered, .notFound:
                    try service.register()
                case .requiresApproval:
                    SMAppService.openSystemSettingsLoginItems()
                case .enabled:
                    break
                @unknown default:
                    throw LaunchAtLoginError.unknownStatus
                }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
        } catch {
            lastError = error.localizedDescription
            logger.error("Login Item update failed: \(error.localizedDescription, privacy: .public)")
        }

        refresh()
        logger.info("Login Item status: \(String(describing: self.service.status), privacy: .public)")
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

private enum LaunchAtLoginError: LocalizedError {
    case unknownStatus

    var errorDescription: String? {
        switch self {
        case .unknownStatus:
            return "macOS returned an unknown Launch at Login status."
        }
    }
}
