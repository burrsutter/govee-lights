import Foundation
import SwiftUI

@MainActor
class GoveeManager: ObservableObject {
    @Published var devices: [GoveeDevice] = []
    @Published var presets: [GoveePreset] = GoveePreset.presets
    @Published var sceneLoadErrors: [String] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let client = GoveeLANClient()
    private let discovery = GoveeDiscovery()

    var anyOn: Bool { devices.contains { $0.state.isOn } }
    var allOn: Bool { !devices.isEmpty && devices.allSatisfy { $0.state.isOn } }

    // MARK: - Lifecycle

    func startUp() async {
        isLoading = true
        let sceneResult = GoveeSceneLoader.loadScenes()
        presets = sceneResult.merging(with: GoveePreset.presets)
        sceneLoadErrors = sceneResult.errors

        let cfg = GoveeConfig.configuredDevices
        // Start with configured devices immediately (offline until proven reachable)
        devices = cfg.map { (name, ip) in GoveeDevice.from(name: name, ip: ip) }
            .sorted { $0.name < $1.name }

        // Background discovery to confirm / add any new IPs (best-effort, may be blocked by sandbox)
        Task {
            let discovered = await discovery.discover(duration: 4)
            // Merge discovered IPs: update existing entries if IP changed, add new
            for (name, ip) in discovered {
                if let idx = devices.firstIndex(where: { $0.name == name }) {
                    if devices[idx].ip != ip {
                        devices[idx].ip = ip
                        devices[idx].isReachable = true
                        devices[idx].lastSeen = Date()
                    }
                } else if !devices.contains(where: { $0.ip == ip }) {
                    // New device not in config
                    devices.append(GoveeDevice.from(name: name, ip: ip))
                }
            }
            devices.sort { $0.name < $1.name }
            // Probe each device with a quick brightness nudge test — for now mark reachable optimistically
            // Real reachability is best-effort: assume configured IPs are reachable until a send fails
            for i in devices.indices {
                devices[i].isReachable = true
                devices[i].lastSeen = Date()
            }
        }

        isLoading = false
    }

    func refresh() async {
        // Govee LAN has no reliable status poll without listening on 4002;
        // for now just mark all as reachable. Future: send devStatus and listen.
        for i in devices.indices {
            devices[i].isReachable = true
            devices[i].lastSeen = Date()
        }
    }

    // MARK: - All lights

    func toggleAll() async {
        let turnOn = !allOn
        for d in devices {
            if turnOn { await client.turnOn(ip: d.ip) } else { await client.turnOff(ip: d.ip) }
        }
        for i in devices.indices { devices[i].state.isOn = turnOn }
    }

    func setAllBrightness(_ v: Int) async {
        let clamped = max(0, min(100, v))
        for d in devices { await client.setBrightness(ip: d.ip, level: clamped) }
        for i in devices.indices { devices[i].state.brightness = clamped }
    }

    func setAllColor(_ c: RGBColor) async {
        for d in devices { await client.setColor(ip: d.ip, r: c.r, g: c.g, b: c.b) }
        for i in devices.indices { devices[i].state.color = c; devices[i].state.kelvin = nil }
    }

    func setAllWhite(kelvin: Int) async {
        let k = max(2000, min(9000, kelvin))
        for d in devices { await client.setWhite(ip: d.ip, kelvin: k) }
        for i in devices.indices { devices[i].state.kelvin = k; devices[i].state.color = nil }
    }

    // MARK: - Per device

    func toggle(_ id: String) async {
        guard let idx = devices.firstIndex(where: { $0.id == id }) else { return }
        let on = !devices[idx].state.isOn
        if on { await client.turnOn(ip: devices[idx].ip) } else { await client.turnOff(ip: devices[idx].ip) }
        devices[idx].state.isOn = on
    }

    func setBrightness(id: String, value: Int) async {
        guard let idx = devices.firstIndex(where: { $0.id == id }) else { return }
        let v = max(0, min(100, value))
        await client.setBrightness(ip: devices[idx].ip, level: v)
        devices[idx].state.brightness = v
    }

    func setColor(id: String, color: RGBColor) async {
        guard let idx = devices.firstIndex(where: { $0.id == id }) else { return }
        await client.setColor(ip: devices[idx].ip, r: color.r, g: color.g, b: color.b)
        devices[idx].state.color = color
        devices[idx].state.kelvin = nil
    }

    func setWhite(id: String, kelvin: Int) async {
        guard let idx = devices.firstIndex(where: { $0.id == id }) else { return }
        let k = max(2000, min(9000, kelvin))
        await client.setWhite(ip: devices[idx].ip, kelvin: k)
        devices[idx].state.kelvin = k
        devices[idx].state.color = nil
    }

    // MARK: - Presets

    func applyPreset(_ preset: GoveePreset) async {
        for (key, setting) in preset.apply {
            if key == "all" {
                for d in devices { await apply(setting, to: d.ip) }
                // update local state to match
                for i in devices.indices { merge(setting, into: &devices[i].state) }
            } else {
                guard let d = devices.first(where: { $0.id == key }) else { continue }
                await apply(setting, to: d.ip)
                if let idx = devices.firstIndex(where: { $0.id == key }) {
                    merge(setting, into: &devices[idx].state)
                }
            }
        }
    }

    private func apply(_ s: GoveePreset.GoveePresetSetting, to ip: String) async {
        if let on = s.on {
            if on { await client.turnOn(ip: ip) } else { await client.turnOff(ip: ip) }
            try? await Task.sleep(for: .milliseconds(80))
        }
        if let b = s.brightness { await client.setBrightness(ip: ip, level: b); try? await Task.sleep(for: .milliseconds(80)) }
        if let c = s.color { await client.setColor(ip: ip, r: c.r, g: c.g, b: c.b) }
        else if let k = s.kelvin { await client.setWhite(ip: ip, kelvin: k) }
    }

    private func merge(_ s: GoveePreset.GoveePresetSetting, into state: inout GoveeState) {
        if let on = s.on { state.isOn = on }
        if let b = s.brightness { state.brightness = b }
        if let c = s.color { state.color = c; state.kelvin = nil }
        else if let k = s.kelvin { state.kelvin = k; state.color = nil }
    }
}
