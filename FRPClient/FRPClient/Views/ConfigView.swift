import SwiftUI

struct ConfigView: View {
    @ObservedObject var viewModel: ConfigViewModel
    @State private var showValidationError = false
    @State private var validationErrors: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader("配置文件", subtitle: "配置服务器连接与代理规则")
                    Spacer()
                    StatusBadge(
                        text: viewModel.processManager.state.rawValue,
                        color: statusColor
                    )
                }

                // Server Settings
                SectionGroup("服务器设置") {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            FormField(title: "服务器地址") {
                                TextField("例如: frp.example.com", text: $viewModel.config.serverAddr)
                                    .borderedInput()
                            }

                            FormField(title: "服务器端口") {
                                TextField("", value: $viewModel.config.serverPort, format: .number)
                                    .borderedInput()
                                    .frame(width: 120)
                            }
                        }

                        HStack(spacing: 16) {
                            FormField(title: "认证 Token") {
                                SecureField("输入 Token", text: $viewModel.config.authToken)
                                    .borderedInput()
                            }

                            FormField(title: "日志级别") {
                                Picker("", selection: $viewModel.config.logLevel) {
                                    ForEach(FRPConfig.LogLevel.allCases) { level in
                                        Text(level.displayName).tag(level)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 160)
                            }
                        }

                        HStack(spacing: 16) {
                            Toggle("启用 TLS 加密", isOn: $viewModel.config.tls)
                                .toggleStyle(.switch)
                                .controlSize(.small)

                            FormField(title: "日志保留天数") {
                                TextField("", value: $viewModel.config.logMaxDays, format: .number)
                                    .borderedInput()
                                    .frame(width: 80)
                            }
                            Spacer()
                        }
                    }
                }

                // Admin API Settings
                SectionGroup("管理面板") {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            FormField(title: "Admin 端口") {
                                TextField("", value: $viewModel.config.adminPort, format: .number)
                                    .borderedInput()
                                    .frame(width: 120)
                            }

                            FormField(title: "Admin 用户名") {
                                TextField("可选", text: $viewModel.config.adminUser)
                                    .borderedInput()
                            }

                            FormField(title: "Admin 密码") {
                                SecureField("可选", text: $viewModel.config.adminPwd)
                                    .borderedInput()
                            }
                        }

                        HStack {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("流量监控通过本地系统工具自动采集 frpc 进程的网络流量，无需额外配置")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }

                // Proxy Rules
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("代理规则")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("(\(viewModel.config.proxyRules.count))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            viewModel.addProxyRule()
                        } label: {
                            Label("添加规则", systemImage: "plus")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    if viewModel.config.proxyRules.isEmpty {
                        CardView {
                            VStack(spacing: 8) {
                                Image(systemName: "tray")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary.opacity(0.4))
                                Text("暂无代理规则")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("点击上方「添加规则」创建内网穿透规则")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                    } else {
                        ForEach($viewModel.config.proxyRules) { $rule in
                            HStack(alignment: .top, spacing: 8) {
                                ProxyRuleRow(rule: $rule)

                                VStack(spacing: 4) {
                                    Button {
                                        viewModel.duplicateProxyRule(rule)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 13))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.secondary)
                                    .help("复制规则")

                                    Button {
                                        viewModel.removeProxyRule(id: rule.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 13))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.red.opacity(0.7))
                                    .help("删除规则")
                                }
                                .padding(.top, 16)
                            }
                        }
                    }
                }

                // Action Buttons
                HStack(spacing: 12) {
                    Button {
                        let errors = viewModel.validateConfig()
                        if errors.isEmpty {
                            viewModel.saveConfig()
                        } else {
                            validationErrors = errors
                            showValidationError = true
                        }
                    } label: {
                        Label("保存配置", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        let errors = viewModel.validateConfig()
                        if errors.isEmpty {
                            viewModel.applyAndRestart()
                        } else {
                            validationErrors = errors
                            showValidationError = true
                        }
                    } label: {
                        Label("应用并重启", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer(minLength: 20)
            }
            .padding(28)
        }
        .frame(minWidth: 600, minHeight: 500)
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

    private var statusColor: Color {
        switch viewModel.processManager.state {
        case .running: return .green
        case .stopped: return .gray
        case .starting, .stopping: return .orange
        case .error, .notInstalled: return .red
        }
    }
}

// MARK: - Form Field helper

struct FormField<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            content
        }
    }
}
