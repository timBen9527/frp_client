import Foundation

struct ProxyRule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var type: ProxyType = .tcp
    var localIP: String = "127.0.0.1"
    var localPort: Int = 8080
    var remotePort: Int = 8080
    var customDomain: String = ""
    var useEncryption: Bool = false
    var useCompression: Bool = false

    enum ProxyType: String, Codable, CaseIterable, Identifiable {
        case tcp = "tcp"
        case udp = "udp"
        case http = "http"
        case https = "https"
        case stcp = "stcp"
        case xtcp = "xtcp"

        var id: String { rawValue }
        var displayName: String {
            rawValue.uppercased()
        }
    }
}
