import SwiftUI

@main
struct GoveeMenuBarApp: App {
    @StateObject private var manager = GoveeManager()
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    var body: some Scene {
        MenuBarExtra {
            GoveeMenuBarView()
                .environmentObject(manager)
                .environmentObject(launchAtLogin)
        } label: {
            Image(systemName: manager.anyOn ? "lightbulb.fill" : "lightbulb.slash.fill")
                .symbolRenderingMode(.monochrome)
                .accessibilityLabel(manager.anyOn ? "Govee lights on" : "Govee lights off")
        }
        .menuBarExtraStyle(.window)
    }
}
