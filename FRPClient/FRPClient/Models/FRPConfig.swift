import Foundation

struct FRPConfig: Codable, Equatable {
    // 基本连接
    var serverAddr: String = ""
    var serverPort: Int = 7000
    var authToken: String = ""

    // 传输设置
    var tls: Bool = false
    var tlsCertFile: String = ""
    var tlsKeyFile: String = ""
    var tlsTrustedCaFile: String = ""
    var transportProtocol: String = "tcp"
    var connectServerLocalIP: String = ""
    var dialServerTimeout: Int = 10
    var dialServerKeepAlive: Int = 7200
    var heartbeatInterval: Int = 30
    var heartbeatTimeout: Int = 90
    var poolCount: Int = 5
    var tcpMux: Bool = true
    var tcpMuxKeepaliveInterval: Int = 60

    // 日志设置
    var logLevel: LogLevel = .info
    var logMaxDays: Int = 3
    var logDisablePrintColor: Bool = false

    // 管理面板（frpc Admin API，用于获取代理状态列表）
    var adminPort: Int = 7400
    var adminUser: String = ""
    var adminPwd: String = ""

    // 其他
    var loginFailExit: Bool = true
    var startProxyNames: String = ""
    var user: String = ""
    var dnsServer: String = ""
    var udpPacketSize: Int = 1500

    // 代理规则
    var proxyRules: [ProxyRule] = []

    enum LogLevel: String, Codable, CaseIterable, Identifiable {
        case trace = "trace"
        case debug = "debug"
        case info = "info"
        case warn = "warn"
        case error = "error"

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .trace: return "追踪 (Trace)"
            case .debug: return "调试 (Debug)"
            case .info: return "信息 (Info)"
            case .warn: return "警告 (Warn)"
            case .error: return "错误 (Error)"
            }
        }
    }
}
