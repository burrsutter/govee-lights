import Foundation
import Darwin

/// Govee LAN API client — UDP unicast to port 4003.
/// Payloads match govee-lights/control.py: turn / brightness / colorwc.
/// No response expected (fire-and-forget), but we expose async throws for future use.
actor GoveeLANClient {
    private let commandPort = GoveeConfig.commandPort

    // MARK: - Public commands (mirrors control.py)

    func turnOn(ip: String) async { await send(ip: ip, cmd: ["cmd": "turn", "data": ["value": 1]]) }
    func turnOff(ip: String) async { await send(ip: ip, cmd: ["cmd": "turn", "data": ["value": 0]]) }

    func setBrightness(ip: String, level: Int) async {
        let clamped = max(0, min(100, level))
        await send(ip: ip, cmd: ["cmd": "brightness", "data": ["value": clamped]])
    }

    func setColor(ip: String, r: Int, g: Int, b: Int) async {
        await send(ip: ip, cmd: [
            "cmd": "colorwc",
            "data": ["color": ["r": max(0,min(255,r)), "g": max(0,min(255,g)), "b": max(0,min(255,b))], "colorTemInKelvin": 0]
        ])
    }

    func setWhite(ip: String, kelvin: Int) async {
        let k = max(2000, min(9000, kelvin))
        await send(ip: ip, cmd: [
            "cmd": "colorwc",
            "data": ["color": ["r": 0, "g": 0, "b": 0], "colorTemInKelvin": k]
        ])
    }

    /// Query device status (optional — not all firmware responds). Listener on 4002.
    func queryStatus(ip: String) async {
        await send(ip: ip, cmd: ["cmd": "devStatus", "data": [:]])
    }

    // MARK: - UDP send

    private func send(ip: String, cmd: [String: Any]) async {
        let envelope: [String: Any] = ["msg": cmd]
        guard let data = try? JSONSerialization.data(withJSONObject: envelope) else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
                guard fd >= 0 else { cont.resume(); return }
                defer { close(fd) }

                var addr = sockaddr_in()
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = in_port_t(UInt16(self.commandPort).bigEndian)
                inet_pton(AF_INET, ip, &addr.sin_addr)

                data.withUnsafeBytes { buf in
                    withUnsafePointer(to: addr) { ptr in
                        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                            _ = sendto(fd, buf.baseAddress, data.count, 0, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }
                cont.resume()
            }
        }
    }
}
