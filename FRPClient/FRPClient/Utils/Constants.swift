import Foundation

enum AppConstants {
    static let appName = "FRP Client"
    static let appBundleId = "com.frpclient.app"

    // GitHub release URL template
    static let frpGitHubReleaseBase = "https://github.com/fatedier/frp/releases/latest/download"

    // Mirror proxies for GitHub
    static let mirrorProxies: [MirrorProxy] = [
        MirrorProxy(name: "gh-proxy", url: "https://gh-proxy.com/"),
        MirrorProxy(name: "ghproxy.net", url: "https://ghproxy.net/"),
        MirrorProxy(name: "ghproxy.homeboyc", url: "https://ghproxy.homeboyc.cn/"),
        MirrorProxy(name: "toolwa", url: "http://toolwa.com/github/"),
        MirrorProxy(name: "github.akams", url: "https://github.akams.cn/"),
        MirrorProxy(name: "直连 (GitHub)", url: "")
    ]

    // Application support directory
    static var appSupportDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FRPClient", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// frpc binary bundled inside the app — read-only, copied at build time
    static var frpcBinaryPath: URL {
        // In release builds, the binary is bundled in Resources
        if let bundled = Bundle.main.url(forResource: "frpc", withExtension: nil) {
            return bundled
        }
        // Fallback for development/debug: check the legacy path
        let legacy = appSupportDir.appendingPathComponent("frpc")
        if FileManager.default.isExecutableFile(atPath: legacy.path) {
            return legacy
        }
        // Return bundled path as default (will be checked for existence by callers)
        return Bundle.main.url(forResource: "frpc", withExtension: nil) ?? legacy
    }

    static var configFilePath: URL {
        appSupportDir.appendingPathComponent("config.json")
    }

    static var tomlFilePath: URL {
        appSupportDir.appendingPathComponent("frpc.toml")
    }

    static var settingsFilePath: URL {
        appSupportDir.appendingPathComponent("settings.json")
    }

    // frpc admin API
    static let defaultAdminPort = 7400
    static let adminAPIBase: String = {
        "http://127.0.0.1:\(defaultAdminPort)"
    }()

    // Dashboard refresh interval
    static let dashboardRefreshInterval: TimeInterval = 3.0
}

struct MirrorProxy: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: String
}
