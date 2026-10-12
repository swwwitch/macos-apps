import AppKit
import CoreLocation
import CoreWLAN
import SystemConfiguration

/// Connection speed per network, measured with macOS's own `networkQuality -I <interface>` (Apple's servers).
/// Only networks that are connected (an IPv4 address other than link-local) are listed, in the service order of System Settings.
@MainActor
final class NetworkSpeedStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = NetworkSpeedStore()

    struct Network: Identifiable, Equatable {
        let id: String      // BSD name (en0)
        let name: String    // service name (Wi-Fi, Thunderbolt Ethernet Slot 2)
        var ssid: String?
        var title: String { ssid.map { "\(name)：\($0)" } ?? name }
    }

    @Published private(set) var networks: [Network] = []
    @Published private(set) var results: [String: String] = [:]
    /// BSD name being measured now.
    @Published private(set) var measuring: String?
    private let location = CLLocationManager()

    override init() {
        super.init()
        location.delegate = self
        refresh()
    }

    func refresh() {
        let connected = Self.connectedInterfaces()
        let wifi = CWWiFiClient.shared().interface()
        networks = Self.services().filter { connected.contains($0.bsd) }.map { service in
            // The SSID is nil without Location Services permission; the name alone is shown then.
            Network(id: service.bsd, name: service.name, ssid: wifi?.interfaceName == service.bsd ? wifi?.ssid() : nil)
        }
    }

    /// Measures each connected network in turn (about 10 seconds each).
    func measureAll() {
        guard measuring == nil else { return }
        requestLocationIfNeeded()
        refresh()
        results = [:]
        let ids = networks.map(\.id)
        Task {
            for id in ids {
                measuring = id
                results[id] = L("測定中…")
                results[id] = await Self.measure(id)
            }
            measuring = nil
        }
    }

    private func requestLocationIfNeeded() {
        if location.authorizationStatus == .notDetermined { location.requestWhenInUseAuthorization() }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.refresh() }
    }

    /// "↓ 240 Mbps　↑ 50 Mbps", or a short failure text.
    private static func measure(_ bsd: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
            process.arguments = ["-I", bsd, "-c", "-M", "10"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                guard let down = (json?["dl_throughput"] as? NSNumber)?.doubleValue, down > 0 else {
                    continuation.resume(returning: L("測定できませんでした"))
                    return
                }
                let up = (json?["ul_throughput"] as? NSNumber)?.doubleValue ?? 0
                continuation.resume(returning: "↓ \(mbps(down))　↑ \(mbps(up))")
            }
            do { try process.run() } catch { continuation.resume(returning: L("測定できませんでした")) }
        }
    }

    /// bits per second → "240 Mbps".
    nonisolated static func mbps(_ bits: Double) -> String {
        let value = bits / 1_000_000
        return value < 10 ? String(format: "%.1f Mbps", value) : "\(Int(value.rounded())) Mbps"
    }

    /// Enabled network services with a BSD interface, in the order of System Settings › Network.
    private static func services() -> [(bsd: String, name: String)] {
        guard let prefs = SCPreferencesCreate(nil, "PodiumAssist" as CFString, nil),
              let set = SCNetworkSetCopyCurrent(prefs),
              let all = SCNetworkSetCopyServices(set) as? [SCNetworkService] else { return [] }
        let order = (SCNetworkSetGetServiceOrder(set) as? [String]) ?? []
        let sorted = all.sorted {
            let a = order.firstIndex(of: (SCNetworkServiceGetServiceID($0) as String?) ?? "") ?? .max
            let b = order.firstIndex(of: (SCNetworkServiceGetServiceID($1) as String?) ?? "") ?? .max
            return a < b
        }
        return sorted.compactMap { service in
            guard SCNetworkServiceGetEnabled(service),
                  let interface = SCNetworkServiceGetInterface(service),
                  let bsd = SCNetworkInterfaceGetBSDName(interface) as String?,
                  let name = SCNetworkServiceGetName(service) as String? else { return nil }
            return (bsd, name)
        }
    }

    /// Interfaces that are up and have an IPv4 address other than link-local (169.254.x.x, e.g. an idle Thunderbolt Bridge).
    private static func connectedInterfaces() -> Set<String> {
        var result = Set<String>()
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return result }
        defer { freeifaddrs(list) }
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            let flags = Int32(entry.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0,
                  let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) else { continue }
            let ipv4 = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            if ipv4 >> 16 == 0xA9FE { continue }
            result.insert(String(cString: entry.ifa_name))
        }
        return result
    }
}
