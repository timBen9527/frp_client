import SwiftUI

@main
struct FRPClientApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var selectedTab: MainView.Tab? = nil
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("FRP 客户端", id: "main") {
            MainView(
                processManager: appDelegate.processManager,
                configViewModel: appDelegate.configViewModel,
                dashboardViewModel: appDelegate.dashboardViewModel,
                settingsViewModel: appDelegate.settingsViewModel,
                externalSelectedTab: $selectedTab
            )
            .onAppear {
                setupAppDelegateCallbacks()
                autoStartIfNeeded()
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 960, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("服务") {
                Button("启动") {
                    appDelegate.processManager.start()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appDelegate.processManager.isRunning)

                Button("停止") {
                    appDelegate.processManager.stop()
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])
                .disabled(!appDelegate.processManager.isRunning)

                Button("重启") {
                    appDelegate.processManager.restart()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }

    private func setupAppDelegateCallbacks() {
        // Connect stdout traffic push to TrafficMonitor
        let dv = appDelegate.dashboardViewModel
        appDelegate.processManager.onTrafficPush = { [weak dv] proxies in
            dv?.trafficMonitor.handlePushData(proxies)
        }

        // Connect status bar traffic display
        appDelegate.connectTrafficUpdates()

        // Window close handling: in menuBar mode, SwiftUI WindowGroup bypasses
        // NSWindowDelegate.windowShouldClose and destroys the window anyway.
        // When the window closes, switch to accessory mode to hide the Dock icon.
        // The window will be recreated by openMainWindow() via reopen.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow,
                  window.styleMask.contains(.titled),
                  !window.className.contains("StatusBar"),
                  !window.className.contains("Popover") else { return }

            let settings = appDelegate.settingsViewModel.settings
            guard settings.displayMode == .menuBar else { return }

            // Switch to accessory mode to hide the Dock icon after window closes
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
            }
        }

        appDelegate.onOpenMainWindow = {
            // openMainWindow() in AppDelegate handles activationPolicy + window display
        }

        appDelegate.openMainWindowAction = { [openWindow] in
            openWindow(id: "main")
        }

        appDelegate.onOpenDashboard = {
            selectedTab = .dashboard
            NSApp.activate(ignoringOtherApps: true)
        }

        appDelegate.onOpenSettings = {
            selectedTab = .settings
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func autoStartIfNeeded() {
        let settings = ConfigManager.shared.loadSettings()
        // Sync login item registration with autoStart setting.
        // If autoStart is enabled, ensure the app is registered as a login item.
        appDelegate.settingsViewModel.syncLaunchAtLogin()
        if settings.autoStart && appDelegate.processManager.state != .running {
            appDelegate.processManager.start()
        }
    }
}



