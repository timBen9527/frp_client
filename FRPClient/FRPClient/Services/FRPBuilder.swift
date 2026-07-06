import Foundation

/// Provides information about the locally built frpc binary.
/// The actual build (clone, patch, compile) happens in an Xcode Build Phase script,
/// not at runtime.
/// All subprocess calls are cached lazily and preloaded on a background thread
/// to avoid blocking the main thread.
final class FRPBuilder {

    // MARK: - Cached Results

    private let lock = NSLock()
    private var _goVersion: String?
    private var _goAvailable: Bool?
    private var _gitAvailable: Bool?
    private var _frpcVersion: String?
    private var _sourceTag: String?
    private var _binaryInstalled: Bool?

    // MARK: - Paths

    var sourceDir: URL {
        AppConstants.appSupportDir.appendingPathComponent("frp-src", isDirectory: true)
    }

    var outputBinaryPath: URL {
        AppConstants.frpcBinaryPath
    }

    // MARK: - Init (preload in background)

    init() {
        preloadAllInBackground()
    }

    private func preloadAllInBackground() {
        // Trigger all cache loads on a background queue so no main-thread blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.isBinaryInstalled
            _ = self.isGoAvailable
            _ = self.goVersion
            _ = self.isGitAvailable
            _ = self.installedVersion
            _ = self.sourceTag
        }
    }

    // MARK: - Public API (non-blocking once cached)

    var isBinaryInstalled: Bool {
        lock.lock()
        if let cached = _binaryInstalled { lock.unlock(); return cached }
        lock.unlock()

        let installed = FileManager.default.fileExists(atPath: outputBinaryPath.path) &&
                        FileManager.default.isExecutableFile(atPath: outputBinaryPath.path)

        lock.lock()
        _binaryInstalled = installed
        lock.unlock()
        return installed
    }

    var isGoAvailable: Bool {
        lock.lock()
        if let cached = _goAvailable { lock.unlock(); return cached }
        lock.unlock()

        let available = runCheck(args: ["go", "version"])

        lock.lock()
        _goAvailable = available
        lock.unlock()
        return available
    }

    var goVersion: String {
        lock.lock()
        if let cached = _goVersion { lock.unlock(); return cached }
        lock.unlock()

        let version = runAndCapture(args: ["go", "version"]) ?? "未安装"

        lock.lock()
        _goVersion = version
        lock.unlock()
        return version
    }

    var isGitAvailable: Bool {
        lock.lock()
        if let cached = _gitAvailable { lock.unlock(); return cached }
        lock.unlock()

        let available = runCheck(args: ["git", "--version"])

        lock.lock()
        _gitAvailable = available
        lock.unlock()
        return available
    }

    var installedVersion: String {
        lock.lock()
        if let cached = _frpcVersion { lock.unlock(); return cached }
        lock.unlock()

        guard isBinaryInstalled else {
            lock.lock(); _frpcVersion = "未安装"; lock.unlock()
            return "未安装"
        }
        let version = runAndCapture(executable: outputBinaryPath, args: ["--version"]) ?? "未知"

        lock.lock()
        _frpcVersion = version
        lock.unlock()
        return version
    }

    var sourceTag: String {
        lock.lock()
        if let cached = _sourceTag { lock.unlock(); return cached }
        lock.unlock()

        let gitDir = sourceDir
        guard FileManager.default.fileExists(atPath: gitDir.appendingPathComponent(".git").path) else {
            lock.lock(); _sourceTag = "未克隆"; lock.unlock()
            return "未克隆"
        }
        let tag = runAndCapture(args: ["git", "-C", sourceDir.path, "describe", "--tags", "--abbrev=0"]) ?? ""

        lock.lock()
        _sourceTag = tag
        lock.unlock()
        return tag
    }

    // MARK: - Private Helpers

    private func runCheck(args: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func runAndCapture(executable: URL? = nil, args: [String]) -> String? {
        let process = Process()
        if let exe = executable {
            process.executableURL = exe
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        }
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return result?.isEmpty == true ? nil : result
        } catch {
            return nil
        }
    }
}
