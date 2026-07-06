import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var processManager: FRPProcessManager
    @ObservedObject var configViewModel: ConfigViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(alignment: .center) {
                    SectionHeader("流量监控", subtitle: "实时监控 frp 代理流量与连接状态")
                    Spacer()
                    StatusBadge(
                        text: monitoringStatusText,
                        color: monitoringStatusColor
                    )
                }

                // Error banner
                if !viewModel.errorMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(viewModel.errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orange.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.12), lineWidth: 0.5)
                    )
                }

                // Real-time Speed Cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    SpeedCard(
                        title: "实时上传速度",
                        speed: viewModel.currentSpeedOut,
                        icon: "arrow.up",
                        color: .green
                    )
                    SpeedCard(
                        title: "实时下载速度",
                        speed: viewModel.currentSpeedIn,
                        icon: "arrow.down",
                        color: .accentColor
                    )
                }

                // Daily Traffic + Connections
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    MetricCard(title: "今日接收", value: viewModel.totalBytesIn.formattedByteSize,
                               icon: "arrow.down", color: .accentColor)
                    MetricCard(title: "今日发送", value: viewModel.totalBytesOut.formattedByteSize,
                               icon: "arrow.up", color: .green)
                    MetricCard(title: "当前连接", value: "\(viewModel.totalConnections)",
                               icon: "point.3.connected.trianglepath.dotted", color: .orange)
                    MetricCard(title: "代理数量", value: "\(viewModel.proxyStats.count)",
                               icon: "server.rack", color: .purple)
                }

                // Traffic Chart
                SectionGroup("流量趋势") {
                    VStack(alignment: .leading, spacing: 14) {
                        // Chart legend with live speed
                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Circle().fill(Color.accentColor).frame(width: 7, height: 7)
                                Text("↓ 下载")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(formatSpeed(viewModel.currentSpeedIn))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.accentColor)
                            }
                            HStack(spacing: 6) {
                                Circle().fill(.green).frame(width: 7, height: 7)
                                Text("↑ 上传")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(formatSpeed(viewModel.currentSpeedOut))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }

                        if viewModel.dataPoints.count >= 2 {
                            Chart {
                                ForEach(viewModel.dataPoints) { point in
                                    AreaMark(
                                        x: .value("时间", point.timestamp),
                                        y: .value("接收", point.bytesIn)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.accentColor.opacity(0.20), .accentColor.opacity(0.02)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)

                                    LineMark(
                                        x: .value("时间", point.timestamp),
                                        y: .value("接收", point.bytesIn)
                                    )
                                    .foregroundStyle(by: .value("类型", "接收"))
                                    .interpolationMethod(.catmullRom)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                                    AreaMark(
                                        x: .value("时间", point.timestamp),
                                        y: .value("发送", point.bytesOut)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green.opacity(0.20), .green.opacity(0.02)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)

                                    LineMark(
                                        x: .value("时间", point.timestamp),
                                        y: .value("发送", point.bytesOut)
                                    )
                                    .foregroundStyle(by: .value("类型", "发送"))
                                    .interpolationMethod(.catmullRom)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                                }
                            }
                            .chartForegroundStyleScale([
                                "接收": Color.accentColor,
                                "发送": .green
                            ])
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisGridLine()
                                        .foregroundStyle(Color.secondary.opacity(0.06))
                                    AxisValueLabel {
                                        if let bytes = value.as(Int.self) {
                                            Text(Int64(bytes).formattedByteSize)
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .chartXAxis {
                                AxisMarks { value in
                                    AxisGridLine()
                                        .foregroundStyle(Color.secondary.opacity(0.06))
                                    AxisValueLabel {
                                        if let date = value.as(Date.self) {
                                            Text(date.timeString)
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .frame(height: 220)
                        } else {
                            VStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.05))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "chart.xyaxis.line")
                                        .font(.system(size: 24, weight: .light))
                                        .foregroundColor(.accentColor.opacity(0.4))
                                }
                                Text(emptyChartMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                // Proxy Stats Table
                SectionGroup("代理状态") {
                    VStack(alignment: .leading, spacing: 10) {
                        if viewModel.proxyStats.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundColor(.secondary.opacity(0.3))
                                Text(emptyTableMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            VStack(spacing: 0) {
                                // Table header
                                HStack(spacing: 0) {
                                    Text("代理名称")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("类型").frame(width: 55)
                                    Text("接收").frame(width: 80, alignment: .trailing)
                                    Text("发送").frame(width: 80, alignment: .trailing)
                                    Text("连接").frame(width: 50, alignment: .center)
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.primary.opacity(0.03))
                                )

                                ForEach(Array(viewModel.proxyStats.enumerated()), id: \.element.id) { index, stat in
                                    HStack(spacing: 0) {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(.green)
                                                .frame(width: 6, height: 6)
                                            Text(stat.proxyName)
                                                .font(.system(size: 12, weight: .medium))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .lineLimit(1)
                                        }
                                        GlassPill(stat.proxyType, color: proxyTypeColor(stat.proxyType))
                                            .frame(width: 55)
                                        Text(stat.bytesIn.formattedByteSize)
                                            .font(.system(size: 11, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundColor(.accentColor)
                                            .frame(width: 80, alignment: .trailing)
                                        Text(stat.bytesOut.formattedByteSize)
                                            .font(.system(size: 11, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundColor(.green)
                                            .frame(width: 80, alignment: .trailing)
                                        Text("\(stat.currentConnections)")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundColor(.orange)
                                            .frame(width: 50, alignment: .center)
                                    }
                                    .padding(.vertical, 9)
                                    .padding(.horizontal, 10)
                                    .background(index % 2 == 0 ? Color.clear : Color.primary.opacity(0.02))

                                    if index < viewModel.proxyStats.count - 1 {
                                        Rectangle()
                                            .fill(Color.primary.opacity(0.04))
                                            .frame(height: 0.5)
                                            .padding(.leading, 10)
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(28)
        }
        .frame(minWidth: 700, minHeight: 580)
        .onChange(of: processManager.state) { newState in
            handleProcessStateChange(newState)
        }
        .onAppear {
            handleProcessStateChange(processManager.state)
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    // MARK: - Helpers

    private func proxyTypeColor(_ type: String) -> Color {
        switch type.uppercased() {
        case "TCP": return .accentColor
        case "UDP": return .green
        case "HTTP": return .orange
        case "HTTPS": return .purple
        case "STCP": return .pink
        case "XTCP": return .red
        default: return .secondary
        }
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.2f MB/s", bytesPerSecond / 1024 / 1024)
        }
    }

    private func handleProcessStateChange(_ state: FRPProcessManager.ProcessState) {
        if state == .running {
            viewModel.startMonitoring(config: configViewModel.config) {
                self.processManager.currentPID
            }
        } else {
            viewModel.stopMonitoring()
        }
    }

    private var monitoringStatusColor: Color {
        if !processManager.isRunning { return .gray }
        if !viewModel.errorMessage.isEmpty { return .orange }
        return .green
    }

    private var monitoringStatusText: String {
        if !processManager.isRunning { return "未启动" }
        if !viewModel.errorMessage.isEmpty { return "连接异常" }
        if viewModel.proxyStats.isEmpty { return "采集中" }
        return "监控中"
    }

    private var emptyChartMessage: String {
        if !processManager.isRunning {
            return "请先启动 frpc 服务以查看流量趋势"
        } else if viewModel.isMonitoring {
            return "正在采集数据..."
        } else {
            return "等待数据..."
        }
    }

    private var emptyTableMessage: String {
        if !processManager.isRunning {
            return "请先启动 frpc 服务以查看代理状态"
        } else if viewModel.isMonitoring {
            return "暂无代理数据"
        } else {
            return "等待数据..."
        }
    }
}

// MARK: - Speed Card

struct SpeedCard: View {
    let title: String
    let speed: Double
    let icon: String
    let color: Color

    @State private var isHovered = false

    private var speedValue: String {
        if speed < 1024 {
            return String(format: "%.0f", speed)
        } else if speed < 1024 * 1024 {
            return String(format: "%.1f", speed / 1024)
        } else {
            return String(format: "%.2f", speed / 1024 / 1024)
        }
    }

    private var speedUnit: String {
        if speed < 1024 { return "B/s" }
        else if speed < 1024 * 1024 { return "KB/s" }
        else { return "MB/s" }
    }

    var body: some View {
        CardView(isHovered: isHovered) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.15), color.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                .shadow(color: color.opacity(speed > 0 ? 0.2 : 0.05), radius: 8, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(speedValue)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .monospacedDigit()
                        Text(speedUnit)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 0)

                if speed > 0 {
                    VStack(spacing: 3) {
                        ForEach(0..<3) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(speedIndicatorColor(bar: i))
                                .frame(width: 3, height: 12)
                        }
                    }
                    .opacity(0.6)
                }
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

    private func speedIndicatorColor(bar: Int) -> Color {
        let threshold: Double
        switch bar {
        case 0: threshold = 1024
        case 1: threshold = 1024 * 100
        case 2: threshold = 1024 * 1024
        default: threshold = 0
        }
        return speed >= threshold ? color : color.opacity(0.15)
    }
}
