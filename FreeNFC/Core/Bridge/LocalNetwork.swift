import Foundation

/// Finds the phone's own Wi-Fi IPv4 address so the Computer Reader screen can show a URL a Mac
/// browser can open directly (Bonjour `.local` names aren't always resolvable from a browser).
enum LocalNetwork {
    /// The IPv4 address of the active Wi-Fi interface (`en0`), or nil if not on Wi-Fi.
    static func wifiIPv4Address() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let interface = current.pointee
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                   &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                        address = String(cString: host)
                    }
                }
            }
            pointer = interface.ifa_next
        }
        return address
    }
}
