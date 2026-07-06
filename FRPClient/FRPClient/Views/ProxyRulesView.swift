import SwiftUI

struct ProxyRulesView: View {
    @ObservedObject var viewModel: ConfigViewModel
    @State private var showAddSheet = false
    @State private var editingRule: ProxyRule?
    @State private var ruleToDelete: ProxyRule?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                SectionHeader("代理规则", subtitle: "管理 FRP 代理转发规则 (\(viewModel.config.proxyRules.count) 条)")
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Label("添加规则", systemImage: "plus")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            if viewModel.config.proxyRules.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(viewModel.config.proxyRules.enumerated()), id: \.element.id) { index, rule in
                            ProxyRuleListRow(
                                rule: rule,
                                index: index,
                                totalCount: viewModel.config.proxyRules.count,
                                onEdit: {
                                    editingRule = rule
                                },
                                onDelete: {
                                    ruleToDelete = rule
                                    showDeleteConfirmation = true
                                },
                                onMoveUp: {
                                    moveRuleUp(rule)
                                },
                                onMoveDown: {
                                    moveRuleDown(rule)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(isPresented: $showAddSheet) {
            ProxyRuleEditSheet(
                viewModel: viewModel,
                editingRule: nil,
                isPresented: $showAddSheet
            )
        }
        .sheet(item: $editingRule) { rule in
            ProxyRuleEditSheet(
                viewModel: viewModel,
                editingRule: rule,
                isPresented: .init(
                    get: { editingRule != nil },
                    set: { if !$0 { editingRule = nil } }
                )
            )
        }
        .alert("删除规则", isPresented: $showDeleteConfirmation, presenting: ruleToDelete) { rule in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                viewModel.removeProxyRule(id: rule.id)
            }
        } message: { rule in
            Text("确定要删除代理规则「\(rule.name.isEmpty ? "未命名规则" : rule.name)」吗？此操作不可撤销。")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.accentColor.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(.accentColor.opacity(0.4))
            }
            VStack(spacing: 6) {
                Text("暂无代理规则")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                Text("点击右上角\"添加规则\"按钮创建第一条代理规则")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            Button {
                showAddSheet = true
            } label: {
                Label("添加规则", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .clipShape(Capsule())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    private func moveRuleUp(_ rule: ProxyRule) {
        guard let index = viewModel.config.proxyRules.firstIndex(where: { $0.id == rule.id }),
              index > 0 else { return }
        viewModel.config.proxyRules.swapAt(index, index - 1)
        viewModel.saveConfig()
    }

    private func moveRuleDown(_ rule: ProxyRule) {
        guard let index = viewModel.config.proxyRules.firstIndex(where: { $0.id == rule.id }),
              index < viewModel.config.proxyRules.count - 1 else { return }
        viewModel.config.proxyRules.swapAt(index, index + 1)
        viewModel.saveConfig()
    }
}

// MARK: - Proxy Rule List Row

struct ProxyRuleListRow: View {
    let rule: ProxyRule
    let index: Int
    let totalCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @State private var isHovered = false

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

    private var typeIcon: String {
        switch rule.type {
        case .tcp: return "arrow.left.arrow.right"
        case .udp: return "dot.radiowaves.left.and.right"
        case .http: return "globe"
        case .https: return "lock"
        case .stcp: return "person.2"
        case .xtcp: return "point.3.connected.trianglepath.dotted"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Index indicator
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.4))
                .frame(width: 24)

            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ruleColor.opacity(isHovered ? 0.18 : 0.1))
                    .frame(width: 34, height: 34)
                Image(systemName: typeIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ruleColor)
            }
            .padding(.trailing, 10)

            // Rule info
            VStack(alignment: .leading, spacing: 3) {
                Text(rule.name.isEmpty ? "未命名规则" : rule.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    GlassPill(rule.type.displayName, color: ruleColor)
                    Text("\(rule.localIP):\(rule.localPort)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    if rule.type == .tcp || rule.type == .udp {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(ruleColor.opacity(0.5))
                        Text(":\(rule.remotePort)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if !rule.customDomain.isEmpty {
                        Text("· \(rule.customDomain)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            // Tags
            HStack(spacing: 6) {
                if rule.useEncryption {
                    TagLabel(icon: "lock.shield.fill", text: "加密", color: .green)
                }
                if rule.useCompression {
                    TagLabel(icon: "arrow.up.arrow.down.circle.fill", text: "压缩", color: .accentColor)
                }
            }

            // Actions (shown on hover)
            if isHovered {
                HStack(spacing: 1) {
                    actionButton(icon: "chevron.up", action: onMoveUp, disabled: index == 0)
                    actionButton(icon: "chevron.down", action: onMoveDown, disabled: index == totalCount - 1)

                    Divider()
                        .frame(height: 18)
                        .padding(.horizontal, 5)

                    actionButton(icon: "pencil", action: onEdit)
                    actionButton(icon: "trash", action: onDelete, tint: .red)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color(.controlBackgroundColor) : Color(.controlBackgroundColor).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isHovered
                        ? ruleColor.opacity(0.2)
                        : Color.primary.opacity(0.06),
                    lineWidth: isHovered ? 1 : 0.5
                )
        )
        .shadow(
            color: isHovered ? ruleColor.opacity(0.06) : Color.clear,
            radius: isHovered ? 6 : 0,
            x: 0,
            y: isHovered ? 2 : 0
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private func actionButton(icon: String, action: @escaping () -> Void, disabled: Bool = false, tint: Color = .secondary) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(disabled ? .secondary.opacity(0.25) : tint)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(disabled ? Color.clear : tint.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Tag Label

struct TagLabel: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

// MARK: - Proxy Rule Edit Sheet (Add / Edit)

struct ProxyRuleEditSheet: View {
    @ObservedObject var viewModel: ConfigViewModel
    let editingRule: ProxyRule?
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var type: ProxyRule.ProxyType = .tcp
    @State private var localIP: String = "127.0.0.1"
    @State private var localPort: String = ""
    @State private var remotePort: String = ""
    @State private var customDomain: String = ""
    @State private var useEncryption: Bool = false
    @State private var useCompression: Bool = false

    private var isEditing: Bool { editingRule != nil }

    private var currentTypeColor: Color {
        switch type {
        case .tcp: return .accentColor
        case .udp: return .green
        case .http: return .orange
        case .https: return .purple
        case .stcp: return .pink
        case .xtcp: return .red
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [currentTypeColor.opacity(0.15), currentTypeColor.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(currentTypeColor.opacity(0.2), lineWidth: 0.5)
                        )
                    Image(systemName: isEditing ? "pencil" : "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(currentTypeColor)
                }
                .shadow(color: currentTypeColor.opacity(0.12), radius: 4, x: 0, y: 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isEditing ? "编辑代理规则" : "添加代理规则")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(isEditing ? "修改端口转发规则配置" : "配置新的端口转发规则")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            // Form content
            ScrollView {
                VStack(spacing: 20) {
                    // Protocol type selector
                    FormField(title: "协议类型") {
                        HStack(spacing: 6) {
                            ForEach(ProxyRule.ProxyType.allCases) { t in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { type = t }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: typeIcon(for: t))
                                            .font(.system(size: 10, weight: .medium))
                                        Text(t.displayName)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                    }
                                    .foregroundColor(type == t ? .white : .secondary)
                                    .frame(minWidth: 44)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(type == t ? currentTypeColor : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .strokeBorder(
                                                type == t ? Color.clear : Color.primary.opacity(0.08),
                                                lineWidth: 0.5
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                        }
                    }

                    // Name & port section
                    CardView {
                        VStack(spacing: 16) {
                            FormField(title: "规则名称") {
                                TextField("例如: Web 服务", text: $name)
                                    .borderedInput()
                            }

                            HStack(spacing: 12) {
                                FormField(title: "本地 IP") {
                                    TextField("127.0.0.1", text: $localIP)
                                        .borderedInput()
                                }
                                FormField(title: "本地端口") {
                                    TextField("8080", text: $localPort)
                                        .borderedInput()
                                        .frame(width: 90)
                                }
                                if type == .tcp || type == .udp {
                                    FormField(title: "远程端口") {
                                        TextField("8080", text: $remotePort)
                                            .borderedInput()
                                            .frame(width: 90)
                                    }
                                }
                            }

                            if type == .http || type == .https {
                                FormField(title: "自定义域名") {
                                    TextField("example.com", text: $customDomain)
                                        .borderedInput()
                                }
                            }
                        }
                    }

                    // Options
                    CardView {
                        HStack(spacing: 24) {
                            HStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(useEncryption ? Color.green.opacity(0.12) : Color.secondary.opacity(0.06))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: useEncryption ? "lock.shield.fill" : "lock.open")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(useEncryption ? .green : .secondary)
                                }
                                Text("传输加密")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Toggle("", isOn: $useEncryption)
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                    .labelsHidden()
                            }

                            HStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(useCompression ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: useCompression ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(useCompression ? .accentColor : .secondary)
                                }
                                Text("传输压缩")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Toggle("", isOn: $useCompression)
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                    .labelsHidden()
                            }
                        }
                    }

                    // Preview
                    CardView {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(currentTypeColor.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                Image(systemName: typeIcon(for: type))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(currentTypeColor)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(name.isEmpty ? "未命名规则" : name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                HStack(spacing: 6) {
                                    GlassPill(type.displayName, color: currentTypeColor)
                                    Text("\(localIP):\(localPort.isEmpty ? "8080" : localPort)")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    if type == .tcp || type == .udp {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary.opacity(0.4))
                                        Text(":\(remotePort.isEmpty ? "8080" : remotePort)")
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                if useEncryption {
                                    HStack(spacing: 3) {
                                        Image(systemName: "lock.shield.fill")
                                            .font(.system(size: 8))
                                        Text("加密")
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .foregroundColor(.green)
                                }
                                if useCompression {
                                    HStack(spacing: 3) {
                                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                                            .font(.system(size: 8))
                                        Text("压缩")
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            // Footer
            HStack(spacing: 12) {
                Button {
                    isPresented = false
                } label: {
                    Text("取消")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .clipShape(Capsule())
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button {
                    saveRule()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isEditing ? "checkmark" : "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isEditing ? "保存修改" : "添加规则")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Capsule())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 520, height: 560)
        .background(
            LinearGradient(
                colors: [currentTypeColor.opacity(0.04), Color.clear, currentTypeColor.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            if let rule = editingRule {
                name = rule.name
                type = rule.type
                localIP = rule.localIP
                localPort = String(rule.localPort)
                remotePort = String(rule.remotePort)
                customDomain = rule.customDomain
                useEncryption = rule.useEncryption
                useCompression = rule.useCompression
            }
        }
    }

    private func saveRule() {
        let lp = Int(localPort) ?? 8080
        let rp = Int(remotePort) ?? 8080

        let rule = ProxyRule(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            localIP: localIP.trimmingCharacters(in: .whitespaces),
            localPort: lp > 0 && lp <= 65535 ? lp : 8080,
            remotePort: rp > 0 && rp <= 65535 ? rp : 8080,
            customDomain: customDomain.trimmingCharacters(in: .whitespaces),
            useEncryption: useEncryption,
            useCompression: useCompression
        )

        if let existingRule = editingRule {
            // Update existing rule
            if let index = viewModel.config.proxyRules.firstIndex(where: { $0.id == existingRule.id }) {
                var updated = rule
                updated.id = existingRule.id // preserve original ID
                viewModel.config.proxyRules[index] = updated
            }
        } else {
            // Add new rule
            viewModel.config.proxyRules.append(rule)
        }

        viewModel.saveConfig()
        isPresented = false
    }

    private func typeIcon(for t: ProxyRule.ProxyType) -> String {
        switch t {
        case .tcp: return "arrow.left.arrow.right"
        case .udp: return "dot.radiowaves.left.and.right"
        case .http: return "globe"
        case .https: return "lock"
        case .stcp: return "person.2"
        case .xtcp: return "point.3.connected.trianglepath.dotted"
        }
    }
}
