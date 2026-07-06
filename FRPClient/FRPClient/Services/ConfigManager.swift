import Foundation

final class ConfigManager {

    static let shared = ConfigManager()

    private init() {}

    // MARK: - Load / Save FRPConfig (JSON)

    func loadConfig() -> FRPConfig {
        let path = AppConstants.configFilePath
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let config = try? JSONDecoder().decode(FRPConfig.self, from: data) else {
            return FRPConfig()
        }
        return config
    }

    func saveConfig(_ config: FRPConfig) throws {
        let data = try JSONEncoder().encode(config)
        try data.write(to: AppConstants.configFilePath, options: .atomic)
    }

    // MARK: - Load / Save AppSettings (JSON)

    func loadSettings() -> AppSettings {
        let path = AppConstants.settingsFilePath
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func saveSettings(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        try data.write(to: AppConstants.settingsFilePath, options: .atomic)
    }
}
