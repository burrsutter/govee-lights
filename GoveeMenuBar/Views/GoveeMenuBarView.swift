import SwiftUI

struct GoveeMenuBarView: View {
    @EnvironmentObject var manager: GoveeManager
    @EnvironmentObject var launchAtLogin: LaunchAtLoginController
    @State private var linked = true
    @State private var selectedPresetID = GoveePreset.presets.first?.id ?? ""
    @State private var showingPresetPicker = false
    @State private var applyingPresetID: String?

    private var selectedPreset: GoveePreset? {
        manager.presets.first { $0.id == selectedPresetID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightstrip.2")
                Text("Govee Lights").font(.headline)
                Spacer()
                if manager.isLoading { ProgressView().controlSize(.small) }
                else {
                    Button { Task { await manager.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless)
                }
            }

            HStack {
                Button { linked.toggle() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: linked ? "link" : "link.badge.plus")
                        Text(linked ? "Linked" : "Independent").font(.caption)
                    }
                }.buttonStyle(.bordered).controlSize(.small)
                Spacer()
            }

            // Scene selection is separate from activation so browsing never changes the lights.
            HStack(spacing: 8) {
                Button { showingPresetPicker.toggle() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: selectedPreset?.icon ?? "sparkles")
                            .frame(width: 16)
                        Text(selectedPreset?.name ?? "Choose a Scene")
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .popover(isPresented: $showingPresetPicker, arrowEdge: .bottom) {
                    GoveeScenePickerView(
                        presets: manager.presets,
                        selection: $selectedPresetID,
                        isPresented: $showingPresetPicker
                    )
                }

                Button {
                    guard let preset = selectedPreset else { return }
                    applyingPresetID = preset.id
                    Task {
                        await manager.applyPreset(preset)
                        applyingPresetID = nil
                    }
                } label: {
                    if applyingPresetID != nil {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Apply")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPreset == nil || applyingPresetID != nil)
                .help("Apply the selected scene")
            }

            if !manager.sceneLoadErrors.isEmpty {
                Label(
                    "\(manager.sceneLoadErrors.count) scene file\(manager.sceneLoadErrors.count == 1 ? "" : "s") skipped",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption2)
                .foregroundStyle(.orange)
                .help(manager.sceneLoadErrors.joined(separator: "\n"))
            }

            Divider()

            if linked { GoveeAllLightsView() }

            if !manager.devices.isEmpty {
                if !linked {
                    ForEach(manager.devices) { d in
                        GoveeLightControlView(device: d, alwaysExpanded: true)
                        if d.id != manager.devices.last?.id { Divider() }
                    }
                } else {
                    Divider()
                    ForEach(manager.devices) { d in GoveeLightControlView(device: d) }
                }
            } else if !manager.isLoading {
                Text("No lights — check .env GOVEE_LIGHT_IPS or LAN Control").font(.caption).foregroundStyle(.secondary)
            }

            Divider()
            HStack {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)

                if launchAtLogin.requiresApproval {
                    Button("Review…") { launchAtLogin.openLoginItemsSettings() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .help("Approve Govee Lights in System Settings")
                }
                Spacer()
            }

            if let error = launchAtLogin.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            HStack {
                Text("\(manager.devices.filter(\.isReachable).count)/\(manager.devices.count) connected")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.borderless).font(.caption)
            }
        }
        .padding()
        .frame(width: 380)
        .task { await manager.startUp() }
        .onAppear { launchAtLogin.refresh() }
    }
}
