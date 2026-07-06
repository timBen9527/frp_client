import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    private let builder = FRPBuilder()

    @State private var frpcVersion: String = ""
    @State private var frpcInstalled = false
    @State private var goVersion: String = ""
    @State private var goAvailable = false
    @State private var gitAvailable = false
    @State private var sourceTag: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SectionHeader("设置", subtitle: "自定义应用行为与显示方式")

                // Display Mode
                SectionGroup("显示模式") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("选择应用程序的显示方式")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)

                        ForEach(AppSettings.DisplayMode.allCases) { mode in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            viewModel.settings.displayMode == mode
                                                ? AnyShapeStyle(LinearGradient(
                                                    colors: [Color.accentColor.opacity(0.15), Color.purple.opacity(0.08)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ))
                                                : AnyShapeStyle(Color.clear)
                                        )
                                        .frame(width: 40, height: 40)
                                    Image(systemName: modeIcon(mode))
                                        .font(.system(size: 18))
                                        .foregroundColor(viewModel.settings.displayMode == mode ? .accentColor : .secondary.opacity(0.5))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(modeDescription(mode))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()

                                if viewModel.settings.displayMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(viewModel.settings.displayMode == mode ? Color.accentColor.opacity(0.05) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        viewModel.settings.displayMode == mode ? Color.accentColor.opacity(0.2) : Color.clear,
                                        lineWidth: 0.5
                                    )
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.updateDisplayMode(mode)
                                }
                            }
                        }

                        if viewModel.needsRestart {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                Text("显示模式变更需要重启应用才能生效")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 6)
                        }
                    }
                }

                // Startup Settings
                SectionGroup("启动设置") {
                    VStack(spacing: 0) {
                        settingsRow(
                            title: "开机自启",
                            subtitle: "系统启动时自动启动",
                            icon: "play.circle",
                            color: .green
                        ) {
                            Toggle("", isOn: $viewModel.settings.autoStart)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }

                        Divider().padding(.leading, 44)
                    }
                }

                // About
                SectionGroup("关于") {
                    VStack(spacing: 0) {
                        envRow(icon: "app.badge", label: "应用版本", value: appVersion, color: .accentColor)
                        Divider().padding(.leading, 44)
                        envRow(icon: "cube.box", label: "FRP 版本", value: frpcVersionText, color: frpcVersionColor)
                    }
                    .padding(.vertical, 4)
                }

                // Data Management
                SectionGroup("数据管理") {
                    HStack(spacing: 12) {
                        Button {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: AppConstants.appSupportDir.path)
                        } label: {
                            Label("打开数据目录", systemImage: "folder")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        Button(role: .destructive) {
                            viewModel.resetAllSettings()
                        } label: {
                            Label("重置所有设置", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // Save Button
                HStack {
                    Spacer()
                    Button {
                        viewModel.saveSettings()
                    } label: {
                        Label("保存设置", systemImage: "checkmark")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Spacer(minLength: 20)
            }
            .padding(28)
        }
        .frame(minWidth: 500, minHeight: 450)
        .task {
            loadFRPCInfo()
        }
        .alert("提示", isPresented: $viewModel.showSaveAlert) {
            Button("确定") {}
        } message: {
            Text(viewModel.saveMessage)
        }
    }

    // MARK: - Async Preload

    private func loadFRPCInfo() {
        Task.detached(priority: .userInitiated) { [builder] in
            // builder properties are thread-safe, preload from background
            let installed = builder.isBinaryInstalled
            let version = builder.installedVersion
            let goVer = builder.goVersion
            let goAvail = builder.isGoAvailable
            let gitAvail = builder.isGitAvailable
            let tag = builder.sourceTag

            await MainActor.run {
                self.frpcInstalled = installed
                self.frpcVersion = version
                self.goVersion = goVer
                self.goAvailable = goAvail
                self.gitAvailable = gitAvail
                self.sourceTag = tag
            }
        }
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var frpcVersionText: String {
        frpcVersion.isEmpty ? builder.installedVersion : frpcVersion
    }

    private var frpcVersionColor: Color {
        frpcInstalled ? .green : .secondary
    }

    // MARK: - Helpers

    private func envRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func settingsRow<Accessory: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            accessory()
        }
        .padding(.vertical, 8)
    }

    private func modeIcon(_ mode: AppSettings.DisplayMode) -> String {
        switch mode {
        case .dock: return "dock.rectangle"
        case .menuBar: return "menubar.rectangle"
        }
    }

    private func modeDescription(_ mode: AppSettings.DisplayMode) -> String {
        switch mode {
        case .dock: return "在 Dock 栏显示应用图标"
        case .menuBar: return "在菜单栏显示应用图标"
        }
    }
}
