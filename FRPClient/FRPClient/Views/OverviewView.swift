import SwiftUI

struct OverviewView: View {
    @ObservedObject var processManager: FRPProcessManager
    @ObservedObject var configViewModel: ConfigViewModel
    @ObservedObject var dashboardViewModel: DashboardViewModel

    private let builder = FRPBuilder()

    @State private var frpcInstalled = false
    @State private var frpcVersion: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                SectionHeader("系统概览", subtitle: "FRP客户端 运行状态总览")

                // Status banner
                statusBanner

                // Real-time metrics (visible when running)
                if processManager.isRunning {
                    realTimeMetrics
                }

                // Config cards
                configCards

                Spacer(minLength: 20)
            }
            .padding(28)
        }
        .frame(minWidth: 600, minHeight: 500)
        .task {
            loadFRPCInfo()
        }
    }

    // MARK: - Real-time Metrics

    private var realTimeMetrics: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ], spacing: 14) {
            MiniMetricCard(
                icon: "arrow.up",
                label: "上传速度",
                value: formatSpeed(dashboardViewModel.currentSpeedOut),
                color: .green
            )
            MiniMetricCard(
                icon: "arrow.down",
                label: "下载速度",
                value: formatSpeed(dashboardViewModel.currentSpeedIn),
                color: .accentColor
            )
            MiniMetricCard(
                icon: "point.3.connected.trianglepath.dotted",
                label: "当前连接",
                value: "\(dashboardViewModel.totalConnections)",
                color: .orange
            )
            MiniMetricCard(
                icon: "server.rack",
                label: "代理数量",
                value: "\(dashboardViewModel.proxyStats.count)",
                color: .purple
            )
        }
    }

    // MARK: - Config Cards

    private var configCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ], spacing: 14) {
            ConfigInfoCard(
                icon: "antenna.radiowaves.left.and.right",
                iconColor: processStatusColor,
                title: "FRPC 状态",
                value: processManager.state.rawValue,
                subtitle: processManager.isRunning ? "进程运行中" : "进程未启动"
            )
            ConfigInfoCard(
                icon: "server.rack",
                iconColor: configViewModel.config.serverAddr.isEmpty ? .gray : .accentColor,
                title: "服务器",
                value: configViewModel.config.serverAddr.isEmpty ? "未配置" : configViewModel.config.serverAddr,
                subtitle: "端口 \(configViewModel.config.serverPort)"
            )
            ConfigInfoCard(
                icon: "doc.text",
                iconColor: configViewModel.config.proxyRules.isEmpty ? .gray : .accentColor,
                title: "代理规则",
                value: "\(configViewModel.config.proxyRules.count) 条",
                subtitle: configViewModel.config.proxyRules.isEmpty ? "暂无规则" : "已配置就绪"
            )
            ConfigInfoCard(
                icon: "cube.box",
                iconColor: frpcInstalled ? .green : .orange,
                title: "FRP 客户端",
                value: frpcInstalled ? "已安装" : "未安装",
                subtitle: frpcInstalled ? frpcVersion : "需从源码编译"
            )
            ConfigInfoCard(
                icon: "list.bullet.rectangle",
                iconColor: .teal,
                title: "日志级别",
                value: configViewModel.config.logLevel.displayName,
                subtitle: "保留 \(configViewModel.config.logMaxDays) 天"
            )
            ConfigInfoCard(
                icon: "externaldrive",
                iconColor: .indigo,
                title: "配置存储",
                value: "本地 JSON",
                subtitle: "Application Support"
            )
        }
    }

    // MARK: - Async Preload

    private func loadFRPCInfo() {
        Task.detached(priority: .userInitiated) { [builder] in
            let installed = builder.isBinaryInstalled
            let version = builder.installedVersion
            await MainActor.run {
                self.frpcInstalled = installed
                self.frpcVersion = version
            }
        }
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(processManager.isRunning ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08))
                    .frame(width: 40, height: 40)
                Image(systemName: processManager.isRunning ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(processManager.isRunning ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(processManager.isRunning ? "FRP 服务运行正常" : "FRP 服务未启动")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text(processManager.isRunning
                     ? "所有代理规则已生效，流量正在转发中"
                     : "点击右上角「启动」开始内网穿透服务")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            StatusBadge(
                text: processManager.state.rawValue,
                color: processStatusColor
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((processManager.isRunning ? Color.green : Color.secondary).opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder((processManager.isRunning ? Color.green : Color.secondary).opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.2f MB/s", bytesPerSecond / 1024 / 1024)
        }
    }

    private var processStatusColor: Color {
        switch processManager.state {
        case .running: return .green
        case .stopped: return .gray
        case .starting, .stopping: return .orange
        case .error, .notInstalled: return .red
        }
    }
}

// MARK: - Mini Metric Card (Overview real-time)

struct MiniMetricCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    @State private var isHovered = false

    var body: some View {
        CardView(isHovered: isHovered) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.10))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Config Info Card (Overview)

struct ConfigInfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String

    @State private var isHovered = false

    var body: some View {
        CardView(isHovered: isHovered) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.10))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}
