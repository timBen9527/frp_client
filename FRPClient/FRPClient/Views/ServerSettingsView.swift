import SwiftUI

struct ServerSettingsView: View {
    @ObservedObject var viewModel: ConfigViewModel
    @State private var selectedCategory: SettingsCategory = .connection
    @State private var showValidationError = false
    @State private var validationErrors: [String] = []

    enum SettingsCategory: String, CaseIterable {
        case connection = "连接"
        case transport = "传输"
        case security = "安全"
        case logging = "日志"
//        case admin = "管理"
        case advanced = "高级"

        var icon: String {
            switch self {
            case .connection: return "wifi"
            case .transport: return "arrow.up.arrow.down"
            case .security: return "lock.shield"
            case .logging: return "doc.text"
//            case .admin: return "gearshape"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header + Category Tabs
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader("服务器设置", subtitle: "配置 FRP 服务器连接参数与传输选项")
                    Spacer()
                }

                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SettingsCategory.allCases, id: \.self) { category in
                            CategoryTab(
                                title: category.rawValue,
                                icon: category.icon,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Settings Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedCategory {
                    case .connection:
                        connectionSection
                    case .transport:
                        transportSection
                    case .security:
                        securitySection
                    case .logging:
                        loggingSection
                    case .advanced:
                        advancedSection
                    }
                }
                .padding(24)
            }

            // Footer bar
            Divider()

            HStack {
                Spacer()
                Button {
                    let errors = viewModel.validateConfig()
                    if errors.isEmpty {
                        viewModel.saveConfig()
                    } else {
                        validationErrors = errors
                        showValidationError = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 12, weight: .semibold))
                        Text("保存配置")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 700, minHeight: 520)
        .alert("配置验证错误", isPresented: $showValidationError) {
            Button("确定") {}
        } message: {
            Text(validationErrors.joined(separator: "\n"))
        }
        .alert("提示", isPresented: $viewModel.showSaveAlert) {
            Button("确定") {}
        } message: {
            Text(viewModel.saveMessage)
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        SectionGroup("基本连接") {
            VStack(spacing: 12) {
                FormRow(leading: "服务器地址") {
                    TextField("例如: frp.example.com", text: $viewModel.config.serverAddr)
                        .borderedInput()
                }
                FormRow(leading: "服务器端口") {
                    TextField("7000", value: $viewModel.config.serverPort, format: .number)
                        .borderedInput()
                        .frame(width: 120)
                }
                FormRow(leading: "认证 Token") {
                    SecureField("输入 Token", text: $viewModel.config.authToken)
                        .borderedInput()
                }
                FormRow(leading: "用户名 (user)") {
                    TextField("可选, 代理名称前缀", text: $viewModel.config.user)
                        .borderedInput()
                }
            }
        }
    }

    // MARK: - Transport

    private var transportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionGroup("传输设置") {
                VStack(spacing: 12) {
                    FormRow(leading: "传输协议") {
                        Picker("", selection: $viewModel.config.transportProtocol) {
                            Text("TCP").tag("tcp")
                            Text("KCP").tag("kcp")
                            Text("QUIC").tag("quic")
                            Text("WebSocket").tag("websocket")
                            Text("WSS").tag("wss")
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    FormRow(leading: "连接池大小") {
                        TextField("", value: $viewModel.config.poolCount, format: .number)
                            .borderedInput()
                            .frame(width: 100)
                    }
                    FormRow(leading: "本地出口 IP") {
                        TextField("可选, 留空为默认", text: $viewModel.config.connectServerLocalIP)
                            .borderedInput()
                    }
                    FormRow(leading: "DNS 服务器") {
                        TextField("可选, 例如 8.8.8.8", text: $viewModel.config.dnsServer)
                            .borderedInput()
                    }
                    Divider()
                        .padding(.vertical, 4)
                    FormRow(leading: "TCP 多路复用") {
                        Toggle("", isOn: $viewModel.config.tcpMux)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                    }
                    FormRow(leading: "Keepalive 间隔") {
                        TextField("秒", value: $viewModel.config.tcpMuxKeepaliveInterval, format: .number)
                            .borderedInput()
                            .frame(width: 100)
                    }
                }
            }

            SectionGroup("超时与心跳") {
                VStack(spacing: 12) {
                    FormRow(leading: "拨号超时") {
                        TextField("秒", value: $viewModel.config.dialServerTimeout, format: .number)
                            .borderedInput()
                            .frame(width: 100)
                    }
                    FormRow(leading: "拨号 Keepalive") {
                        TextField("秒", value: $viewModel.config.dialServerKeepAlive, format: .number)
                            .borderedInput()
                            .frame(width: 100)
                    }
                    FormRow(leading: "心跳间隔") {
                        TextField("秒", value: $viewModel.config.heartbeatInterval, format: .number)
                            .borderedInput()
                            .frame(width: 100)
                    }
                    FormRow(leading: "心跳超时") {
                        TextField("秒", value: $viewModel.config.heartbeatTimeout, format: .number)
                            .borderedInput()
                            .frame(width: 100)
                    }
                    FormRow(leading: "UDP 包大小") {
                        TextField("字节", value: $viewModel.config.udpPacketSize, format: .number)
                            .borderedInput()
                            .frame(width: 100)
                    }
                }
            }
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        SectionGroup("TLS 加密") {
            VStack(spacing: 12) {
                FormRow(leading: "启用 TLS") {
                    Toggle("", isOn: $viewModel.config.tls)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }

                if viewModel.config.tls {
                    Divider()
                        .padding(.vertical, 4)
                    FormRow(leading: "证书文件") {
                        TextField("可选, 证书路径", text: $viewModel.config.tlsCertFile)
                            .borderedInput()
                    }
                    FormRow(leading: "私钥文件") {
                        TextField("可选, 私钥路径", text: $viewModel.config.tlsKeyFile)
                            .borderedInput()
                    }
                    FormRow(leading: "CA 证书") {
                        TextField("可选, CA 路径", text: $viewModel.config.tlsTrustedCaFile)
                            .borderedInput()
                    }
                }
            }
        }
    }

    // MARK: - Logging

    private var loggingSection: some View {
        SectionGroup("日志设置") {
            VStack(spacing: 12) {
                FormRow(leading: "日志级别") {
                    Picker("", selection: $viewModel.config.logLevel) {
                        ForEach(FRPConfig.LogLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                FormRow(leading: "保留天数") {
                    TextField("", value: $viewModel.config.logMaxDays, format: .number)
                        .borderedInput()
                        .frame(width: 80)
                }
                Divider()
                    .padding(.vertical, 4)
                FormRow(leading: "禁用颜色输出") {
                    Toggle("", isOn: $viewModel.config.logDisablePrintColor)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
            }
        }
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        SectionGroup("其他选项") {
            VStack(spacing: 12) {
                FormRow(leading: "登录失败退出") {
                    Toggle("", isOn: $viewModel.config.loginFailExit)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
                FormRow(leading: "启动代理") {
                    TextField("留空全部, 例如: ssh,web", text: $viewModel.config.startProxyNames)
                        .borderedInput()
                }
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.processManager.state {
        case .running: return .green
        case .stopped: return .gray
        case .starting, .stopping: return .orange
        case .error, .notInstalled: return .red
        }
    }
}
