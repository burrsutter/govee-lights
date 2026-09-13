import Foundation
import Darwin

/// LAN discovery via UDP multicast 239.255.255.250:4001, responses on :4002
/// Matches govee-lights/discover.py
struct GoveeDiscovery: Sendable {
    struct Discovered: Sendable {
        let ip: String
        let sku: String?
        let device: String?
        let raw: [String: Any]
    }

    func discover(duration: TimeInterval = GoveeConfig.scanDuration) async -> [String: String] {
        // Returns [name: ip] by merging discovered IPs with known names, or GoveeConfig defaults.
        let found = await scan(duration: duration)
        if found.isEmpty {
            // discovery failed (sandbox / not on LAN) — return configured defaults
            return GoveeConfig.configuredDevices
        }
        // Map discovered IPs to names: prefer known name for matching IP, else invent
        var byIP = [String: Discovered]()
        for d in found { byIP[d.ip] = d }

        var out: [String: String] = [:]
        // Keep known names where IP matches discovered, or where discovery missed
        let configured = GoveeConfig.configuredDevices
        for (name, cfgIP) in configured {
            if byIP[cfgIP] != nil {
                out[name] = cfgIP
            } else if let match = byIP.first(where: { $0.value.sku != nil }) {
                // If IPs shifted (DHCP), try to match by SKU order — keep configured name but discovered IP
                // For now, keep configured IP; caller will probe both
                out[name] = cfgIP
                _ = match
            } else {
                out[name] = cfgIP
            }
        }
        // Any discovered IP not in configured gets a generic name
        for (ip, _) in byIP where !out.values.contains(ip) {
            let gen = "govee-\(ip.replacingOccurrences(of: ".", with: "-"))"
            out[gen] = ip
        }
        return out
    }

    /// Raw UDP scan — returns Discovered list
    func scan(duration: TimeInterval = GoveeConfig.scanDuration) async -> [Discovered] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Self.blockingScan(duration: duration)
                cont.resume(returning: result)
            }
        }
    }

    private static func blockingScan(duration: TimeInterval) -> [Discovered] {
        let sendMsg = try? JSONSerialization.data(withJSONObject: ["msg": ["cmd": "scan", "data": ["account_topic": "reserve"]]])

        // Receive socket on 0.0.0.0:4002
        let recvFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard recvFD >= 0 else { return [] }
        defer { close(recvFD) }

        var yes: Int32 = 1
        setsockopt(recvFD, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        // SO_REUSEPORT for multicast on macOS
        setsockopt(recvFD, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<Int32>.size))

        var recvAddr = sockaddr_in()
        recvAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        recvAddr.sin_family = sa_family_t(AF_INET)
        recvAddr.sin_port = in_port_t(UInt16(GoveeConfig.recvPort).bigEndian)
        recvAddr.sin_addr.s_addr = INADDR_ANY.bigEndian

        let bindResult = withUnsafePointer(to: recvAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(recvFD, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { return [] }

        // Non-blocking + timeout via select
        var flags = fcntl(recvFD, F_GETFL)
        fcntl(recvFD, F_SETFL, flags | O_NONBLOCK)

        let sendFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sendFD >= 0 else { return [] }
        defer { close(sendFD) }

        var sendAddr = sockaddr_in()
        sendAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        sendAddr.sin_family = sa_family_t(AF_INET)
        sendAddr.sin_port = in_port_t(UInt16(GoveeConfig.scanPort).bigEndian)
        inet_pton(AF_INET, GoveeConfig.multicastGroup, &sendAddr.sin_addr)

        var found: [String: Discovered] = [:]
        let deadline = Date().addingTimeInterval(duration)
        var lastSend = Date.distantPast

        while Date() < deadline {
            if Date().timeIntervalSince(lastSend) > 2 {
                if let data = sendMsg {
                    data.withUnsafeBytes { buf in
                        withUnsafePointer(to: sendAddr) { ptr in
                            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                                _ = sendto(sendFD, buf.baseAddress, data.count, 0, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                            }
                        }
                    }
                }
                lastSend = Date()
            }

            var buf = [UInt8](repeating: 0, count: 4096)
            var src = sockaddr_in()
            var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = buf.withUnsafeMutableBytes { mbuf in
                withUnsafeMutablePointer(to: &src) { srcPtr in
                    srcPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                        recvfrom(recvFD, mbuf.baseAddress, 4096, 0, sockPtr, &srcLen)
                    }
                }
            }
            if n > 0, let json = try? JSONSerialization.jsonObject(with: Data(buf[0..<n])) as? [String: Any],
               let msg = json["msg"] as? [String: Any], let data = msg["data"] as? [String: Any] {
                let ip = (data["ip"] as? String) ?? ""
                let sku = data["sku"] as? String
                let device = data["device"] as? String
                // Derive IP from sender if missing
                var senderIP = ""
                var s = src
                var dst = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &s.sin_addr, &dst, socklen_t(INET_ADDRSTRLEN))
                senderIP = String(cString: dst)
                let finalIP = ip.isEmpty ? senderIP : ip
                if !finalIP.isEmpty {
                    found[finalIP] = Discovered(ip: finalIP, sku: sku, device: device, raw: data)
                }
            } else {
                usleep(100_000) // 100ms
            }
        }
        return Array(found.values)
    }
}
