import Foundation
import SwiftUI

struct GoveeDevice: Identifiable, Sendable, Equatable, Hashable {
    let id: String          // name, e.g. floor-lamp-1
    var name: String        // display name
    var ip: String
    var sku: String?
    var deviceType: String?
    var isReachable: Bool = false
    var lastSeen: Date?
    var state: GoveeState

    static func from(name: String, ip: String, sku: String? = nil) -> GoveeDevice {
        GoveeDevice(
            id: name,
            name: name,
            ip: ip,
            sku: sku,
            isReachable: false,
            state: GoveeState.default
        )
    }
}

struct GoveeState: Sendable, Equatable, Hashable {
    var isOn: Bool
    var brightness: Int      // 0-100
    var color: RGBColor?     // nil = white mode
    var kelvin: Int?         // 2000-9000, nil = color mode

    static let `default` = GoveeState(isOn: false, brightness: 100, color: nil, kelvin: 4000)

    var displayColor: Color {
        if let c = color { return Color(red: Double(c.r)/255, green: Double(c.g)/255, blue: Double(c.b)/255) }
        // temperature → approximate tint
        return .white
    }
}

struct RGBColor: Sendable, Equatable, Hashable, Codable {
    var r, g, b: Int
    init(_ r: Int, _ g: Int, _ b: Int) {
        self.r = max(0, min(255, r)); self.g = max(0, min(255, g)); self.b = max(0, min(255, b))
    }
    static let red = RGBColor(255, 0, 0)
    static let green = RGBColor(0, 255, 0)
    static let blue = RGBColor(0, 0, 255)
    static let warmWhite = RGBColor(255, 180, 100)
}

// MARK: - Presets (mirrors govee-lights/scenes + Elgato presets)

struct GoveePreset: Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String
    let apply: [String: GoveePresetSetting]

    struct GoveePresetSetting: Sendable {
        var on: Bool?
        var brightness: Int?
        var color: RGBColor?
        var kelvin: Int?
    }

    static let presets: [GoveePreset] = [
        GoveePreset(id: "all-white", name: "Bright White", icon: "sun.max.fill", apply: [
            "all": GoveePresetSetting(on: true, brightness: 100, color: nil, kelvin: 4000)
        ]),
        GoveePreset(id: "movie-night", name: "Movie", icon: "film.fill", apply: [
            "floor-lamp-1": GoveePresetSetting(on: true, brightness: 30, kelvin: 3000),
            "floor-lamp-2": GoveePresetSetting(on: false),
            "neon-rope-black": GoveePresetSetting(on: true, brightness: 50, color: RGBColor(0,0,128)),
            "neon-rope-white": GoveePresetSetting(on: true, brightness: 50, color: RGBColor(0,0,128)),
        ]),
        GoveePreset(id: "vibrant", name: "Vibrant", icon: "paintpalette.fill", apply: [
            "all": GoveePresetSetting(on: true, brightness: 100, color: RGBColor(255, 0, 128))
        ]),
        GoveePreset(id: "ambient", name: "Ambient", icon: "moon.fill", apply: [
            "all": GoveePresetSetting(on: true, brightness: 15, kelvin: 2700)
        ]),
        GoveePreset(id: "80s-tie-dye", name: "80s Tie-Dye", icon: "sparkles", apply: [
            "floor-lamp-1": GoveePresetSetting(on: true, brightness: 100, color: RGBColor(255, 0, 128)),
            "floor-lamp-2": GoveePresetSetting(on: true, brightness: 100, color: RGBColor(0, 255, 255)),
            "neon-rope-black": GoveePresetSetting(on: true, brightness: 100, color: RGBColor(255, 200, 0)),
            "neon-rope-white": GoveePresetSetting(on: true, brightness: 100, color: RGBColor(128, 0, 255)),
        ]),
        GoveePreset(id: "all-off", name: "All Off", icon: "power", apply: [
            "all": GoveePresetSetting(on: false)
        ]),
    ]
}
