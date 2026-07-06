import Foundation

final class TOMLGenerator {

    static func generate(from config: FRPConfig) -> String {
        var lines: [String] = []

        lines.append("# FRP Client 配置文件")
        lines.append("# 由 FRP Client 自动生成，请勿手动修改")
        lines.append("")

        // 基本连接
        lines.append("serverAddr = \"\(config.serverAddr)\"")
        lines.append("serverPort = \(config.serverPort)")

        if !config.authToken.isEmpty {
            lines.append("")
            lines.append("auth.method = \"token\"")
            lines.append("auth.token = \"\(config.authToken)\"")
        }

        // 传输设置
        if config.transportProtocol != "tcp" {
            lines.append("transport.protocol = \"\(config.transportProtocol)\"")
        }
        if !config.connectServerLocalIP.isEmpty {
            lines.append("transport.connectServerLocalIP = \"\(config.connectServerLocalIP)\"")
        }
        if config.dialServerTimeout != 10 {
            lines.append("transport.dialServerTimeout = \(config.dialServerTimeout)")
        }
        if config.dialServerKeepAlive != 7200 {
            lines.append("transport.dialServerKeepAlive = \(config.dialServerKeepAlive)")
        }
        if config.heartbeatInterval != 30 {
            lines.append("transport.heartbeatInterval = \(config.heartbeatInterval)")
        }
        if config.heartbeatTimeout != 90 {
            lines.append("transport.heartbeatTimeout = \(config.heartbeatTimeout)")
        }
        if config.poolCount != 5 {
            lines.append("transport.poolCount = \(config.poolCount)")
        }
        if !config.tcpMux {
            lines.append("transport.tcpMux = false")
        }
        if config.tcpMuxKeepaliveInterval != 60 {
            lines.append("transport.tcpMuxKeepaliveInterval = \(config.tcpMuxKeepaliveInterval)")
        }

        // TLS 设置
        if config.tls {
            lines.append("")
            lines.append("transport.tls.enable = true")
            if !config.tlsCertFile.isEmpty {
                lines.append("transport.tls.certFile = \"\(config.tlsCertFile)\"")
            }
            if !config.tlsKeyFile.isEmpty {
                lines.append("transport.tls.keyFile = \"\(config.tlsKeyFile)\"")
            }
            if !config.tlsTrustedCaFile.isEmpty {
                lines.append("transport.tls.trustedCaFile = \"\(config.tlsTrustedCaFile)\"")
            }
        }

        // 日志设置
        lines.append("")
        lines.append("log.level = \"\(config.logLevel.rawValue)\"")
        lines.append("log.maxDays = \(config.logMaxDays)")
        if config.logDisablePrintColor {
            lines.append("log.disablePrintColor = true")
        }

        // 管理面板
        if config.adminPort > 0 {
            lines.append("")
            lines.append("webServer.addr = \"127.0.0.1\"")
            lines.append("webServer.port = \(config.adminPort)")
            if !config.adminUser.isEmpty {
                lines.append("webServer.user = \"\(config.adminUser)\"")
                lines.append("webServer.password = \"\(config.adminPwd)\"")
            }
        }

        // 其他设置
        if !config.loginFailExit {
            lines.append("")
            lines.append("loginFailExit = false")
        }
        if !config.user.isEmpty {
            lines.append("user = \"\(config.user)\"")
        }
        if !config.dnsServer.isEmpty {
            lines.append("dnsServer = \"\(config.dnsServer)\"")
        }
        if config.udpPacketSize != 1500 {
            lines.append("udpPacketSize = \(config.udpPacketSize)")
        }
        if !config.startProxyNames.isEmpty {
            let names = config.startProxyNames.split(separator: ",").map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }.joined(separator: ", ")
            lines.append("start = [\(names)]")
        }

        // Proxy rules
        for rule in config.proxyRules {
            lines.append("")
            lines.append("[[proxies]]")
            lines.append("name = \"\(rule.name)\"")
            lines.append("type = \"\(rule.type.rawValue)\"")
            lines.append("localIP = \"\(rule.localIP)\"")
            lines.append("localPort = \(rule.localPort)")

            if rule.type == .tcp || rule.type == .udp {
                lines.append("remotePort = \(rule.remotePort)")
            }

            if !rule.customDomain.isEmpty {
                lines.append("customDomains = [\"\(rule.customDomain)\"]")
            }

            if rule.useEncryption {
                lines.append("transport.useEncryption = true")
            }

            if rule.useCompression {
                lines.append("transport.useCompression = true")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func writeToFile(from config: FRPConfig) throws {
        let toml = generate(from: config)
        try toml.write(to: AppConstants.tomlFilePath, atomically: true, encoding: .utf8)
    }
}
