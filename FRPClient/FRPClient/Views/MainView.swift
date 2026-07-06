import SwiftUI

struct MainView: View {
    @ObservedObject var processManager: FRPProcessManager
    @ObservedObject var configViewModel: ConfigViewModel
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Binding var externalSelectedTab: Tab?
    @State private var selectedTab: Tab = .overview

    enum Tab: Hashable {
        case overview
        case serverSettings
        case proxyRules
        case dashboard
        case logs
        case settings
    }

    var body: some View {
        NavigationSplitView {
            List {
                Section {
                    sidebarItem(tab: .overview, icon: "square.grid.2x2", label: "系统概览")
                    sidebarItem(tab: .serverSettings, icon: "gearshape.2", label: "服务器设置")
                    sidebarItem(tab: .proxyRules, icon: "arrow.triangle.branch", label: "代理规则")
                } header: {
                    sidebarHeader("配置")
                }

                Section {
                    sidebarItem(tab: .dashboard, icon: "chart.xyaxis.line", label: "流量监控")
                    sidebarItem(tab: .logs, icon: "doc.text", label: "运行日志")
                } header: {
                    sidebarHeader("系统")
                }

                Section {
                    sidebarItem(tab: .settings, icon: "slider.horizontal.3", label: "应用设置")
                } header: {
                    sidebarHeader("应用")
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(180)
        } detail: {
            detailView
        }
        .frame(minWidth: 960, minHeight: 720)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ToolbarActionButton(
                    title: processManager.isRunning ? "停止" : "启动",
                    icon: processManager.isRunning ? "stop.fill" : "play.fill",
                    color: processManager.isRunning ? .red : .green
                ) {
                    if processManager.isRunning {
                        processManager.stop()
                    } else {
                        processManager.start()
                    }
                }
            }
        }
        .onChange(of: externalSelectedTab) { newTab in
            if let tab = newTab {
                selectedTab = tab
                // Reset after applying so the same tab can be triggered again
                externalSelectedTab = nil
            }
        }
    }

    private func sidebarHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.secondary.opacity(0.45))
            .textCase(.uppercase)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))
    }

    private var sidebarSelectionColor: Color { .accentColor }
    private let sidebarHoverColor = Color.primary.opacity(0.06)

    private func sidebarItem(tab: Tab, icon: String, label: String) -> some View {
        let isSelected = selectedTab == tab
        return SidebarRow(
            icon: icon,
            label: label,
            isSelected: isSelected,
            hasDot: tab == .dashboard && processManager.isRunning,
            sidebarSelectionColor: sidebarSelectionColor,
            sidebarHoverColor: sidebarHoverColor
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTab = tab
        }
        .tag(tab)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .overview:
            OverviewView(
                processManager: processManager,
                configViewModel: configViewModel,
                dashboardViewModel: dashboardViewModel
            )
        case .serverSettings:
            ServerSettingsView(viewModel: configViewModel)
        case .proxyRules:
            ProxyRulesView(viewModel: configViewModel)
        case .dashboard:
            DashboardView(
                viewModel: dashboardViewModel,
                processManager: processManager,
                configViewModel: configViewModel
            )
        case .logs:
            LogsView(processManager: processManager)
        case .settings:
            SettingsView(viewModel: settingsViewModel)
        }
    }
}
