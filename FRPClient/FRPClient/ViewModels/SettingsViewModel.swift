import Foundation
import Combine
import ServiceManagement

@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var settings: AppSettings
    @Published var saveMessage: String = ""
    @Published var showSaveAlert: Bool = false
    @Published var needsRestart: Bool = false

    private let configManager = ConfigManager.shared

    init() {
        self.settings = configManager.loadSettings()
    }

    func saveSettings() {
        do {
            try configManager.saveSettings(settings)
            syncLaunchAtLogin()
            saveMessage = "设置已保存"
            showSaveAlert = true

            if needsRestart {
                saveMessage = "设置已保存，显示模式变更需要重启应用"
                needsRestart = false
            }
        } catch {
            saveMessage = "保存失败: \(error.localizedDescription)"
            showSaveAlert = true
        }
    }

    func updateDisplayMode(_ mode: AppSettings.DisplayMode) {
        if settings.displayMode != mode {
            settings.displayMode = mode
            needsRestart = true
        }
    }

    func resetAllSettings() {
        settings = AppSettings()
        syncLaunchAtLogin()
        saveSettings()
    }

    /// Sync the system login item registration with the current autoStart setting.
    /// When autoStart is enabled, register the app to launch at login.
    /// When autoStart is disabled, unregister it.
    func syncLaunchAtLogin() {
        do {
            if settings.autoStart {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[SettingsViewModel] Failed to sync login item: \(error)")
        }
    }
}
