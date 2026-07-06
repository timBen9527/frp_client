import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settings: AppSettings = ConfigManager.shared.loadSettings()
    private var cancellables = Set<AnyCancellable>()

    // Owned view models — created directly in AppDelegate so they're available
    // before any SwiftUI @StateObject initialization completes.
    let processManager = FRPProcessManager()
    let dashboardViewModel = DashboardViewModel()
    let settingsViewModel = SettingsViewModel()
    lazy var configViewModel = ConfigViewModel(processManager: processManager)

    var onOpenMainWindow: (() -> Void)?
    var onOpenDashboard: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var openMainWindowAction: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent all titled windows from being released when closed.
        // This must be set early so SwiftUI windows survive close events
        // and can be re-shown via makeKeyAndOrderFront.
        for window in NSApp.windows {
            if window.styleMask.contains(.titled) {
                window.isReleasedWhenClosed = false
            }
        }

        let mode = settings.displayMode
        if mode == .menuBar {
            // Start as .regular so SwiftUI creates the main window,
            // then hide it and switch to .accessory.
            NSApp.setActivationPolicy(.regular)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.applyDisplayMode()
            }
        } else {
            applyDisplayMode()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Ensure frpc processes are killed on app quit
        processManager.killAllFRPC()
    }

    /// In menuBar mode, the app should stay alive even when the last window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return settings.displayMode != .menuBar
    }

    private var isOpeningMainWindow = false

    /// When in menuBar mode and the user clicks Dock icon, show the main window.
    /// SwiftUI WindowGroup uses this to recreate the window when it was closed.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if settings.displayMode == .menuBar && !flag && !isOpeningMainWindow {
            openMainWindow()
        }
        return true
    }

    func applyDisplayMode() {
        settings = ConfigManager.shared.loadSettings()
        switch settings.displayMode {
        case .dock:
            NSApp.setActivationPolicy(.regular)
            removeStatusBar()
        case .menuBar:
            // Prepare main windows for menuBar mode: prevent release on close,
            // hide them, then switch to accessory mode.
            for window in NSApp.windows {
                guard window.styleMask.contains(.titled),
                      !window.className.contains("StatusBar"),
                      !window.className.contains("Popover") else { continue }
                window.isReleasedWhenClosed = false
                window.orderOut(nil)
            }
            NSApp.setActivationPolicy(.accessory)
            setupStatusBarIfNeeded()
        }
    }

    // MARK: - Status Bar

    func setupStatusBarIfNeeded() {
        guard statusItem == nil else { return }

        // Use fixed length: traffic view(~80) + padding(2) ≈ 82pt
        statusItem = NSStatusBar.system.statusItem(withLength: 82)

        if let button = statusItem?.button {
            button.wantsLayer = true
            button.image = nil
            button.title = ""
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp])

            // Add traffic view as subview — full custom layout: icon + ↑ speed / ↓ speed
            let tv = TrafficStatusView()
            tv.update(inSpeed: 0, outSpeed: 0, isRunning: false)
            button.addSubview(tv)
            tv.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tv.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 2),
                tv.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2),
                tv.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                tv.heightAnchor.constraint(equalToConstant: 22),
            ])
            trafficView = tv
        }

        // Subscribe to traffic updates for real-time display in the status bar.
        subscribeToTrafficUpdates()
    }

    // MARK: - Status Bar Traffic Display

    private var trafficView: TrafficStatusView?

    /// Called after setupAppDelegate injects the view models.
    /// Ensures the Combine subscription is established even if setupStatusBarIfNeeded
    /// ran before the injection.
    func connectTrafficUpdates() {
        guard trafficView != nil else { return }
        guard cancellables.isEmpty else { return }
        subscribeToTrafficUpdates()
    }

    private func subscribeToTrafficUpdates() {
        let dv = dashboardViewModel

        // Immediately sync the traffic view with current values
        // (covers the case where monitoring already started before subscription).
        let m = dv.trafficMonitor
        trafficView?.update(inSpeed: m.currentSpeedIn, outSpeed: m.currentSpeedOut, isRunning: m.isMonitoring)

        // Merge all three @Published streams: any single property change
        // triggers a UI refresh with the current snapshot of all values.
        Publishers.Merge3(
            dv.trafficMonitor.$currentSpeedIn.map { _ in () },
            dv.trafficMonitor.$currentSpeedOut.map { _ in () },
            dv.trafficMonitor.$isMonitoring.map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self = self, let tv = self.trafficView else { return }
            let m = dv.trafficMonitor
            tv.update(inSpeed: m.currentSpeedIn, outSpeed: m.currentSpeedOut, isRunning: m.isMonitoring)
        }
        .store(in: &cancellables)
    }

    /// Custom view for the status bar button showing real-time traffic in two rows.
    /// Layout:  [icon] ↑ speed (row 1)  ↓ speed (row 2)
    /// Hit-testing is disabled so clicks pass through to the NSStatusBarButton.
    private class TrafficStatusView: NSView {
        private let icon = NSImageView()
        private let upArrow = NSTextField(labelWithString: "↑")
        private let upSpeed = NSTextField(labelWithString: "0 KB/s")
        private let downArrow = NSTextField(labelWithString: "↓")
        private let downSpeed = NSTextField(labelWithString: "0 KB/s")

        private let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        private let arrowFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        private let upColor = NSColor.controlTextColor
        private let downColor = NSColor.systemGreen

        init() {
            super.init(frame: NSRect(x: 0, y: 0, width: 78, height: 22))
            setup()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }

        /// Pass all clicks through to the underlying NSStatusBarButton
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        private func setup() {
            wantsLayer = true

            icon.image = NSImage(systemSymbolName: "network", accessibilityDescription: "FRP 客户端")
            icon.imageScaling = .scaleProportionallyDown
            icon.translatesAutoresizingMaskIntoConstraints = false
            addSubview(icon)

            for tf in [upArrow, upSpeed, downArrow, downSpeed] {
                tf.isBordered = false
                tf.backgroundColor = .clear
                tf.translatesAutoresizingMaskIntoConstraints = false
                addSubview(tf)
            }

            upArrow.font = arrowFont
            upArrow.textColor = upColor
            upArrow.alignment = .center

            upSpeed.font = font
            upSpeed.textColor = NSColor.controlTextColor
            upSpeed.alignment = .right

            downArrow.font = arrowFont
            downArrow.textColor = downColor
            downArrow.alignment = .center

            downSpeed.font = font
            downSpeed.textColor = NSColor.controlTextColor
            downSpeed.alignment = .right

            // Layout: icon(18) | ↑ speed (top) / ↓ speed (bottom)
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: leadingAnchor),
                icon.centerYAnchor.constraint(equalTo: centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 18),
                icon.heightAnchor.constraint(equalToConstant: 18),

                upArrow.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 2),
                upArrow.topAnchor.constraint(equalTo: topAnchor, constant: 2),
                upArrow.widthAnchor.constraint(equalToConstant: 10),
                upArrow.heightAnchor.constraint(equalToConstant: 10),

                upSpeed.leadingAnchor.constraint(equalTo: upArrow.trailingAnchor, constant: 1),
                upSpeed.topAnchor.constraint(equalTo: upArrow.topAnchor),
                upSpeed.trailingAnchor.constraint(equalTo: trailingAnchor),
                upSpeed.heightAnchor.constraint(equalToConstant: 10),

                downArrow.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 2),
                downArrow.topAnchor.constraint(equalTo: upArrow.bottomAnchor, constant: 0),
                downArrow.widthAnchor.constraint(equalToConstant: 10),
                downArrow.heightAnchor.constraint(equalToConstant: 10),

                downSpeed.leadingAnchor.constraint(equalTo: downArrow.trailingAnchor, constant: 1),
                downSpeed.topAnchor.constraint(equalTo: downArrow.topAnchor),
                downSpeed.trailingAnchor.constraint(equalTo: trailingAnchor),
                downSpeed.heightAnchor.constraint(equalToConstant: 10),
            ])
        }

        func update(inSpeed: Double, outSpeed: Double, isRunning: Bool) {
            upSpeed.stringValue = isRunning ? formatSpeed(outSpeed) : "0 KB/s"
            downSpeed.stringValue = isRunning ? formatSpeed(inSpeed) : "0 KB/s"
        }

        private func formatSpeed(_ bytesPerSecond: Double) -> String {
            if bytesPerSecond < 0.5 { return "0 KB/s" }
            if bytesPerSecond < 1024 { return String(format: "%.0f B/s", bytesPerSecond) }
            if bytesPerSecond < 1024 * 1024 {
                return String(format: "%.1f KB/s", bytesPerSecond / 1024)
            }
            return String(format: "%.1f MB/s", bytesPerSecond / 1024 / 1024)
        }
    }

    func removeStatusBar() {
        cancellables.removeAll()
        trafficView?.removeFromSuperview()
        trafficView = nil
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        togglePopover(for: sender)
    }

    private func togglePopover(for sender: NSStatusBarButton) {
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // .transient behavior dismisses the popover when the user clicks outside,
                // but only if the popover window can become key. In accessory mode we need
                // to activate the app first, then show, then explicitly make the popover key.
                NSApp.activate(ignoringOtherApps: true)
                popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
                // After showing, make the popover window key so transient dismissal works
                popover.contentViewController?.view.window?.makeKey()
            }
        } else {
            createPopover()
            NSApp.activate(ignoringOtherApps: true)
            popover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
        }
    }

    private func createPopover() {
        print("[DEBUG] createPopover called")
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 400)
        popover.behavior = .transient

        popover.contentViewController = NSHostingController(rootView:
            StatusBarPopoverView(
                processManager: processManager,
                configViewModel: configViewModel,
                dashboardViewModel: dashboardViewModel,
                onOpenMainWindow: { [weak self] in
                    Task { @MainActor in
                        self?.openMainWindow()
                    }
                },
                onOpenDashboard: { [weak self] in
                    Task { @MainActor in
                        self?.openMainWindow()
                        self?.onOpenDashboard?()
                    }
                },
                onOpenSettings: { [weak self] in
                    Task { @MainActor in
                        self?.openMainWindow()
                        self?.onOpenSettings?()
                    }
                },
                onQuit: {
                    NSApp.terminate(nil)
                }
            )
        )

        self.popover = popover
    }

    func openMainWindow() {
        guard !isOpeningMainWindow else { return }
        isOpeningMainWindow = true

        // Switch to regular mode so Dock icon appears and windows can be shown.
        NSApp.setActivationPolicy(.regular)

        // Close the popover first so it doesn't steal focus.
        popover?.performClose(nil)

        // Show the main window if it exists. If not (SwiftUI destroyed it),
        // use SwiftUI's openWindow action to recreate it.
        let foundWindow = findMainWindow() != nil

        if foundWindow {
            DispatchQueue.main.async {
                self.showMainWindow()
                self.isOpeningMainWindow = false
                self.onOpenMainWindow?()
            }
        } else {
            // Window was destroyed by SwiftUI. Use openWindow(id:) to recreate it.
            NSApp.activate(ignoringOtherApps: true)
            openMainWindowAction?()
            // Pick up the newly created window after SwiftUI has time to render it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showMainWindow()
                self?.isOpeningMainWindow = false
                self?.onOpenMainWindow?()
            }
        }
    }

    /// Find the main SwiftUI window (not status bar / popover).
    private func findMainWindow() -> NSWindow? {
        for window in NSApp.windows {
            guard window.styleMask.contains(.titled),
                  !window.className.contains("StatusBar"),
                  !window.className.contains("Popover") else { continue }
            return window
        }
        return nil
    }

    /// Bring the main window to front, deminiaturize if needed, and
    /// temporarily elevate to floating level so it appears on top.
    private func showMainWindow() {
        guard let window = findMainWindow() else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        if window.isMiniaturized { window.deminiaturize(nil) }
        // Temporarily float to force the window on top of everything.
        let savedLevel = window.level
        window.level = .floating
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            window.level = savedLevel
        }
    }

}
