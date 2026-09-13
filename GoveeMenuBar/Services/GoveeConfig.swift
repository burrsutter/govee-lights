import Foundation

/// Config for Govee LAN control — mirrors the Python `control.py` and `discover.py` setup.
/// Reads from env/.env so IPs aren't hardcoded. Priority: env > .env file > hard-coded defaults.
enum GoveeConfig {
    /// Default devices from govee-lights/README (H6076 + H61D5)
    static let defaultDevices: [String: String] = [
        "floor-lamp-1":    "192.168.4.49",
        "floor-lamp-2":    "192.168.4.28",
        "neon-rope-black": "192.168.4.42",
        "neon-rope-white": "192.168.4.43",
    ]

    static let defaultDeviceOrder = ["floor-lamp-1", "floor-lamp-2", "neon-rope-black", "neon-rope-white"]

    static let multicastGroup = "239.255.255.250"
    static let scanPort = 4001
    static let recvPort = 4002
    static let commandPort = 4003
    static let scanDuration: TimeInterval = 6

    /// Optional env override: GOVEE_LIGHT_IPS=192.168.4.49,192.168.4.28,... (comma-separated, same order as names)
    /// Or per-device: GOVEE_FLOOR_LAMP_1_IP etc — but simplest is GOVEE_LIGHTS_JSON
    static var configuredDevices: [String: String] {
        // 1. JSON blob override: GOVEE_LIGHTS_JSON='{"floor-lamp-1":"192.168.4.49",...}'
        if let json = resolvedValue(forKey: "GOVEE_LIGHTS_JSON"), let data = json.data(using: .utf8),
           let dict = try? JSONDecoder().decode([String: String].self, from: data), !dict.isEmpty {
            return dict
        }
        // 2. Comma-separated IPs with assumed order
        if let raw = resolvedValue(forKey: "GOVEE_LIGHT_IPS"), !raw.isEmpty {
            let ips = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if !ips.isEmpty {
                var out: [String: String] = [:]
                for (i, name) in defaultDeviceOrder.enumerated() where i < ips.count {
                    out[name] = ips[i]
                }
                // extra IPs get generic names
                if ips.count > defaultDeviceOrder.count {
                    for i in defaultDeviceOrder.count..<ips.count {
                        out["govee-\(i+1)"] = ips[i]
                    }
                }
                return out
            }
        }
        // 3. Per-device env vars
        var perDevice: [String: String] = [:]
        var foundAny = false
        for name in defaultDeviceOrder {
            let envKey = "GOVEE_\(name.replacingOccurrences(of: "-", with: "_").uppercased())_IP"
            if let ip = resolvedValue(forKey: envKey), !ip.isEmpty {
                perDevice[name] = ip
                foundAny = true
            }
        }
        if foundAny {
            // fill missing with defaults
            for (k, v) in defaultDevices where perDevice[k] == nil { perDevice[k] = v }
            return perDevice
        }
        return defaultDevices
    }

    // MARK: - dotEnv helpers (shared with Elgato AppConfig pattern)

    private static func resolvedValue(forKey key: String) -> String? {
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty { return env }
        if let v = dotEnvValues()[key] { return v }
        return nil
    }

    private static var cachedDotEnv: [String: String]?
    private static func dotEnvValues() -> [String: String] {
        if let c = cachedDotEnv { return c }
        let parsed = parseDotEnv()
        cachedDotEnv = parsed
        return parsed
    }

    private static func parseDotEnv() -> [String: String] {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let exe = Bundle.main.executableURL {
            var dir = exe.deletingLastPathComponent()
            for _ in 0..<6 {
                candidates.append(dir.appendingPathComponent(".env"))
                candidates.append(dir.appendingPathComponent("../.env"))
                dir = dir.deletingLastPathComponent()
            }
        }
        candidates.append(URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent(".env"))
        candidates.append(URL(fileURLWithPath: fm.homeDirectoryForCurrentUser.path).appendingPathComponent(".config/govee-lights/.env"))

        for url in candidates {
            let std = url.standardizedFileURL
            guard fm.fileExists(atPath: std.path) else { continue }
            if let vals = try? parseFile(at: std), !vals.isEmpty { return vals }
        }
        return [:]
    }

    private static func parseFile(at url: URL) throws -> [String: String] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var out: [String: String] = [:]
        for raw in content.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            var val = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
                val = String(val.dropFirst().dropLast())
            }
            if !key.isEmpty { out[key] = val }
        }
        return out
    }
}
