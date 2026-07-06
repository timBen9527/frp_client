import Foundation

struct AppSettings: Codable, Equatable {
    var displayMode: DisplayMode = .dock
    var autoStart: Bool = false

    enum DisplayMode: String, Codable, CaseIterable, Identifiable {
        case dock = "dock"
        case menuBar = "menuBar"

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .dock: return "Dock 栏"
            case .menuBar: return "状态栏"
            }
        }
    }
}
