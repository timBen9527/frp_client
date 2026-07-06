import SwiftUI

struct ProxyRuleRow: View {
    @Binding var rule: ProxyRule

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [ruleColor.opacity(0.15), ruleColor.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(ruleColor.opacity(0.2), lineWidth: 0.5)
                            )
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ruleColor)
                    }
                    Text(rule.name.isEmpty ? "未命名规则" : rule.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                Spacer()
                GlassPill(rule.type.displayName, color: ruleColor)
            }

            // Fields
            HStack(spacing: 12) {
                FormField(title: "规则名称") {
                    TextField("名称", text: $rule.name)
                        .borderedInput()
                }

                FormField(title: "类型") {
                    Picker("", selection: $rule.type) {
                        ForEach(ProxyRule.ProxyType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .labelsHidden()
                }
            }

            HStack(spacing: 12) {
                FormField(title: "本地 IP") {
                    TextField("127.0.0.1", text: $rule.localIP)
                        .borderedInput()
                }

                FormField(title: "本地端口") {
                    TextField("8080", value: $rule.localPort, format: .number)
                        .borderedInput()
                        .frame(width: 90)
                }

                if rule.type == .tcp || rule.type == .udp {
                    FormField(title: "远程端口") {
                        TextField("8080", value: $rule.remotePort, format: .number)
                            .borderedInput()
                            .frame(width: 90)
                    }
                }
            }

            if rule.type == .http || rule.type == .https {
                FormField(title: "自定义域名") {
                    TextField("example.com", text: $rule.customDomain)
                        .borderedInput()
                }
            }

            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: rule.useEncryption ? "lock.shield.fill" : "lock.open")
                        .font(.system(size: 11))
                        .foregroundColor(rule.useEncryption ? .green : .secondary)
                    Toggle("加密", isOn: $rule.useEncryption)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .font(.system(size: 12))
                }
                HStack(spacing: 6) {
                    Image(systemName: rule.useCompression ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                        .font(.system(size: 11))
                        .foregroundColor(rule.useCompression ? .accentColor : .secondary)
                    Toggle("压缩", isOn: $rule.useCompression)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .font(.system(size: 12))
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.controlBackgroundColor).opacity(0.3))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var ruleColor: Color {
        switch rule.type {
        case .tcp: return .accentColor
        case .udp: return .green
        case .http: return .orange
        case .https: return .purple
        case .stcp: return .pink
        case .xtcp: return .red
        }
    }
}
