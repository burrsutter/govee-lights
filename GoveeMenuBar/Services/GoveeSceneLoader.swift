import Foundation

struct GoveeSceneLoadResult {
    let presets: [GoveePreset]
    let errors: [String]

    func merging(with builtIns: [GoveePreset]) -> [GoveePreset] {
        var byID = Dictionary(uniqueKeysWithValues: builtIns.map { ($0.id, $0) })
        for preset in presets {
            byID[preset.id] = preset
        }
        return byID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

enum GoveeSceneLoader {
    static func loadScenes() -> GoveeSceneLoadResult {
        loadScenes(from: sceneDirectory())
    }

    static func loadScenes(from directory: URL) -> GoveeSceneLoadResult {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return GoveeSceneLoadResult(presets: [], errors: [])
        }

        let sceneFiles = files
            .filter { ["yaml", "yml"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        var presets: [GoveePreset] = []
        var errors: [String] = []

        for file in sceneFiles {
            do {
                presets.append(try parseScene(at: file))
            } catch {
                errors.append("\(file.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return GoveeSceneLoadResult(presets: presets, errors: errors)
    }

    private static func sceneDirectory() -> URL {
        let fm = FileManager.default

        if let override = ProcessInfo.processInfo.environment["GOVEE_SCENES_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath, isDirectory: true)
        }

        let userScenes = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/govee-lights/scenes", isDirectory: true)
        if fm.fileExists(atPath: userScenes.path) {
            return userScenes
        }

        let workingScenes = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("scenes", isDirectory: true)
        if fm.fileExists(atPath: workingScenes.path) {
            return workingScenes
        }

        return userScenes
    }

    private static func parseScene(at url: URL) throws -> GoveePreset {
        let content = try String(contentsOf: url, encoding: .utf8)
        let id = url.deletingPathExtension().lastPathComponent
        guard !id.isEmpty else { throw SceneError.invalid("missing filename") }

        enum Section { case none, all, lights }
        var section = Section.none
        var currentDevice: String?
        var displayName: String?
        var icon: String?
        var settings: [String: GoveePreset.GoveePresetSetting] = [:]

        for (offset, rawLine) in content.components(separatedBy: .newlines).enumerated() {
            let lineNumber = offset + 1
            let line = stripComment(from: rawLine)
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            guard !line.contains("\t") else { throw SceneError.line(lineNumber, "tabs are not supported") }

            let indent = line.prefix { $0 == " " }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colon = trimmed.firstIndex(of: ":") else {
                throw SceneError.line(lineNumber, "expected key: value")
            }

            let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)

            if indent == 0 {
                currentDevice = nil
                switch key {
                case "all":
                    guard value.isEmpty else { throw SceneError.line(lineNumber, "all must contain indented settings") }
                    section = .all
                    settings["all"] = GoveePreset.GoveePresetSetting()
                case "lights":
                    guard value.isEmpty else { throw SceneError.line(lineNumber, "lights must contain devices") }
                    section = .lights
                case "name":
                    displayName = unquoted(value)
                case "icon":
                    icon = unquoted(value)
                case "transition":
                    break // Supported by the Python animator; LAN commands remain immediate.
                default:
                    throw SceneError.line(lineNumber, "unsupported top-level key '\(key)'")
                }
                continue
            }

            if section == .lights, indent == 2, value.isEmpty {
                guard !key.isEmpty else { throw SceneError.line(lineNumber, "missing device name") }
                currentDevice = key
                settings[key] = GoveePreset.GoveePresetSetting()
                continue
            }

            let target: String
            switch section {
            case .all:
                guard indent >= 2 else { throw SceneError.line(lineNumber, "settings under all must be indented") }
                target = "all"
            case .lights:
                guard indent >= 4, let device = currentDevice else {
                    throw SceneError.line(lineNumber, "device settings must be indented beneath a device")
                }
                target = device
            case .none:
                throw SceneError.line(lineNumber, "setting appears before all or lights")
            }

            var setting = settings[target] ?? GoveePreset.GoveePresetSetting()
            try apply(key: key, value: value, to: &setting, line: lineNumber)
            settings[target] = setting
        }

        guard !settings.isEmpty else { throw SceneError.invalid("scene has no all or lights settings") }
        let name = displayName?.isEmpty == false ? displayName! : humanized(id)
        return GoveePreset(id: id, name: name, icon: icon?.isEmpty == false ? icon! : inferredIcon(for: id), apply: settings)
    }

    private static func apply(
        key: String,
        value: String,
        to setting: inout GoveePreset.GoveePresetSetting,
        line: Int
    ) throws {
        switch key {
        case "on":
            switch value.lowercased() {
            case "true", "yes", "on": setting.on = true
            case "false", "no", "off": setting.on = false
            default: throw SceneError.line(line, "on must be true or false")
            }
        case "brightness":
            guard let number = Int(value), (0...100).contains(number) else {
                throw SceneError.line(line, "brightness must be between 0 and 100")
            }
            setting.brightness = number
        case "white", "kelvin":
            guard let number = Int(value), (2000...9000).contains(number) else {
                throw SceneError.line(line, "white must be between 2000K and 9000K")
            }
            setting.kelvin = number
            setting.color = nil
        case "color":
            guard value.hasPrefix("["), value.hasSuffix("]") else {
                throw SceneError.line(line, "color must look like [255, 0, 128]")
            }
            let components = value.dropFirst().dropLast().split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard components.count == 3,
                  let red = Int(components[0]), let green = Int(components[1]), let blue = Int(components[2]),
                  (0...255).contains(red), (0...255).contains(green), (0...255).contains(blue) else {
                throw SceneError.line(line, "color components must be between 0 and 255")
            }
            setting.color = RGBColor(red, green, blue)
            setting.kelvin = nil
        default:
            throw SceneError.line(line, "unsupported setting '\(key)'")
        }
    }

    private static func stripComment(from line: String) -> String {
        var quote: Character?
        for index in line.indices {
            let character = line[index]
            if character == "\"" || character == "'" {
                quote = quote == character ? nil : (quote == nil ? character : quote)
            } else if character == "#", quote == nil {
                return String(line[..<index])
            }
        }
        return line
    }

    private static func unquoted(_ value: String) -> String {
        guard value.count >= 2,
              let first = value.first, let last = value.last,
              (first == "\"" && last == "\"") || (first == "'" && last == "'") else { return value }
        return String(value.dropFirst().dropLast())
    }

    private static func humanized(_ id: String) -> String {
        id.split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map { word in
                let text = String(word)
                guard let first = text.first else { return text }
                return first.uppercased() + text.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func inferredIcon(for id: String) -> String {
        let lower = id.lowercased()
        if lower.contains("off") { return "power" }
        if lower.contains("white") { return "sun.max.fill" }
        if lower.contains("movie") { return "film.fill" }
        if lower.contains("christmas") { return "gift.fill" }
        if lower.contains("ambient") { return "moon.fill" }
        return "sparkles"
    }
}

private enum SceneError: LocalizedError {
    case invalid(String)
    case line(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .line(let number, let message): return "line \(number): \(message)"
        }
    }
}
