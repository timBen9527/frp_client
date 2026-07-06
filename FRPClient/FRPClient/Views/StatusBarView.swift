import SwiftUI
import Combine

struct StatusBarPopoverView: View {
    @ObservedObject var processManager: FRPProcessManager
    @ObservedObject var configViewModel: ConfigViewModel
    @ObservedObject var dashboardViewModel: DashboardViewModel
    var onOpenMainWindow: () -> Void
    var onOpenDashboard: () -> Void
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    // Mirror processManager's lightweight state so the popover body
    // is NOT invalidated every time logs[] changes (every ~1 s).
    @State private var isRunning = false
    @State private var stateText = ""
    @State private var stateSub: AnyCancellable?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text("FRP 客户端")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isRunning ? .green : .gray)
                            .frame(width: 5, height: 5)
                        Text(stateText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                StatusBadge(
                    text: isRunning ? "运行中" : "已停止",
                    color: isRunning ? .green : .gray
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.primary.opacity(0.06), Color.clear, Color.primary.opacity(0.03)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            // Quick Stats
            HStack(spacing: 0) {
                popoverStat(title: "接收", value: dashboardViewModel.totalBytesIn.formattedByteSize, color: .accentColor)
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 1, height: 32)
                popoverStat(title: "发送", value: dashboardViewModel.totalBytesOut.formattedByteSize, color: .green)
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 1, height: 32)
                popoverStat(title: "连接", value: "\(dashboardViewModel.totalConnections)", color: .orange)
            }
            .padding(.vertical, 10)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.primary.opacity(0.03), Color.clear, Color.primary.opacity(0.06)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            // Actions
            VStack(spacing: 2) {
                if isRunning {
                    PopoverMenuItem(title: "停止", icon: "stop.fill", color: .red) {
                        processManager.stop()
                    }
                    PopoverMenuItem(title: "重启", icon: "arrow.triangle.2.circlepath", color: .orange) {
                        processManager.restart()
                    }
                } else {
                    PopoverMenuItem(title: "启动", icon: "play.fill", color: .green) {
                        processManager.start()
                    }
                }

                Rectangle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(height: 1)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)

                PopoverMenuItem(title: "打开主窗口", icon: "macwindow", color: .accentColor) {
                    onOpenMainWindow()
                }
                PopoverMenuItem(title: "流量监控", icon: "chart.line.uptrend.xyaxis", color: .purple) {
                    onOpenDashboard()
                }
                PopoverMenuItem(title: "设置", icon: "gearshape", color: .secondary) {
                    onOpenSettings()
                }

                Rectangle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(height: 1)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)

                PopoverMenuItem(title: "退出", icon: "power", color: .red) {
                    onQuit()
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 280)
        .onAppear {
            syncState()
            subscribeToProcessState()
        }
        .onDisappear {
            stateSub = nil
        }
    }

    private func popoverStat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Process state sync (avoids re-render on logs changes)

    private func syncState() {
        isRunning = processManager.isRunning
        stateText = processManager.state.rawValue
    }

    private func subscribeToProcessState() {
        // Only react to state changes, ignore log additions
        stateSub = processManager.$state
            .receive(on: DispatchQueue.main)
            .sink { newState in
                isRunning = (newState == .running)
                stateText = newState.rawValue
            }
    }
}

struct PopoverMenuItem: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
