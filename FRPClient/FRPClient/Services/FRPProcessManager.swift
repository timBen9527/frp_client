import Foundation
import Combine

@MainActor
final class FRPProcessManager: ObservableObject {

    enum ProcessState: String {
        case stopped = "已停止"
        case running = "运行中"
        case starting = "启动中..."
        case stopping = "停止中..."
        case error = "错误"
        case notInstalled = "未安装"
    }

    @Published var state: ProcessState = .stopped
    @Published var logs: [String] = []
    @Published var lastError: String = ""

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    
    /// Buffer for incomplete stdout lines (traffic JSON may span multiple reads)
    private var stdoutBuffer = ""

    /// Callback invoked when a traffic push JSON line is received from frpc stdout.
    var onTrafficPush: (([ProxyTrafficStats]) -> Void)?

    var isRunning: Bool {
        state == .running
    }

    /// Current frpc process PID, or 0 if not running
    var currentPID: Int32 {
        process?.processIdentifier ?? 0
    }

    init() {
        checkInitialState()
    }

    private func checkInitialState() {
        if !FileManager.default.isExecutableFile(atPath: AppConstants.frpcBinaryPath.path) {
            state = .notInstalled
        }
    }

    func start() {
        guard state != .running, state != .starting else { return }

        // Check binary exists
        guard FileManager.default.isExecutableFile(atPath: AppConstants.frpcBinaryPath.path) else {
            state = .notInstalled
            lastError = "frpc 未安装，请先下载"
            return
        }

        // Check config toml exists
        guard FileManager.default.fileExists(atPath: AppConstants.tomlFilePath.path) else {
            lastError = "配置文件不存在，请先配置"
            state = .error
            return
        }

        // Kill any orphan frpc processes before starting
        killOrphanFRPCProcesses()

        state = .starting
        logs.append("[\(Date().timeString)] 正在启动 frpc...")

        let proc = Process()
        proc.executableURL = AppConstants.frpcBinaryPath
        proc.arguments = ["-c", AppConstants.tomlFilePath.path]
        proc.currentDirectoryURL = AppConstants.appSupportDir

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            
            Task { @MainActor [text] in
                self?.stdoutBuffer.append(text)
                self?.processStdoutBuffer()
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
            let lines = line.components(separatedBy: .newlines).filter { !$0.isEmpty }
            Task { @MainActor in
                for l in lines {
                    self?.logs.append("[\(Date().timeString)] \(l)")
                }
            }
        }

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                if self?.state == .stopping || self?.state == .starting {
                    self?.state = .stopped
                    self?.logs.append("[\(Date().timeString)] frpc 已停止")
                } else if self?.state == .running {
                    self?.state = .error
                    self?.logs.append("[\(Date().timeString)] frpc 意外退出")
                }
            }
        }

        do {
            try proc.run()
            self.process = proc
            self.outputPipe = outPipe
            self.errorPipe = errPipe
            state = .running
            logs.append("[\(Date().timeString)] frpc 已启动 (PID: \(proc.processIdentifier))")
        } catch {
            state = .error
            lastError = "启动失败: \(error.localizedDescription)"
            logs.append("[\(Date().timeString)] 启动失败: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard state == .running || state == .starting, let proc = process else { return }

        state = .stopping
        logs.append("[\(Date().timeString)] 正在停止 frpc...")

        let pid = proc.processIdentifier

        // Unregister readability handlers to avoid retain cycles
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil

        // Override termination handler so restart logic doesn't fire
        proc.terminationHandler = { _ in
            Task { @MainActor in
                self.state = .stopped
                self.logs.append("[\(Date().timeString)] frpc 已停止")
            }
        }

        // Send SIGTERM first (graceful)
        proc.terminate()

        // Force kill after 3 seconds if still running
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
            let stillRunning = kill(pid, 0) == 0
            if stillRunning {
                // SIGKILL — guaranteed termination
                kill(pid, SIGKILL)
                Task { @MainActor in
                    self?.logs.append("[\(Date().timeString)] frpc 进程已强制终止 (PID: \(pid))")
                }
            }
        }
    }

    /// Kill all running frpc processes (used on app quit for cleanup)
    func killAllFRPC() {
        // Terminate our managed process first
        if let proc = process, proc.isRunning {
            let pid = proc.processIdentifier
            outputPipe?.fileHandleForReading.readabilityHandler = nil
            errorPipe?.fileHandleForReading.readabilityHandler = nil
            proc.terminationHandler = nil
            proc.terminate()
            // Give it a brief moment, then SIGKILL
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                if kill(pid, 0) == 0 {
                    kill(pid, SIGKILL)
                }
            }
        }
        // Also find and kill any orphan frpc processes by name
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["-9", "frpc"]
        task.standardOutput = nil
        task.standardError = nil
        try? task.run()
        task.waitUntilExit()
    }

    func restart() {
        guard let proc = process, proc.isRunning else {
            start()
            return
        }

        state = .stopping
        logs.append("[\(Date().timeString)] 正在重启 frpc...")

        // Unregister handlers to avoid retain cycles during restart
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil

        proc.terminationHandler = { _ in
            Task { @MainActor in
                self.state = .stopped
                self.logs.append("[\(Date().timeString)] frpc 已停止")
                self.process = nil
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.start()
            }
        }
        proc.terminate()

        // Safety: force kill after 5 seconds if still hung
        let pid = proc.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            if kill(pid, 0) == 0 {
                kill(pid, SIGKILL)
                Task { @MainActor in
                    self?.logs.append("[\(Date().timeString)] frpc 进程在重启时被强制终止")
                }
            }
        }
    }

    func clearLogs() {
        logs.removeAll()
    }

    // MARK: - Orphan Process Detection

    /// Check for and kill any existing frpc processes not managed by this instance.
    /// This prevents port conflicts when starting a new frpc.
    private func killOrphanFRPCProcesses() {
        // If we already manage a running process, it's not orphan — skip
        if let proc = process, proc.isRunning { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "frpc"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Found running frpc processes — kill them
                logs.append("[\(Date().timeString)] 检测到已有的 frpc 进程，正在终止...")
                let killTask = Process()
                killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                killTask.arguments = ["-9", "frpc"]
                killTask.standardOutput = nil
                killTask.standardError = nil
                try? killTask.run()
                killTask.waitUntilExit()
                // Brief wait to ensure processes are fully terminated
                Thread.sleep(forTimeInterval: 0.3)
                logs.append("[\(Date().timeString)] 已有 frpc 进程已终止")
            }
        } catch {
            // pgrep failed — proceed with start anyway
        }
    }

    // MARK: - Traffic Push Parsing
    
    /// Process buffered stdout content, splitting on newlines.
    /// Handles partial reads where a line may be split across multiple availability callbacks.
    private func processStdoutBuffer() {
        guard !stdoutBuffer.isEmpty else { return }
        
        // Split buffer by newlines; last element may be incomplete
        let parts = stdoutBuffer.components(separatedBy: "\n")
        
        // All complete lines (everything except the last part)
        let completeLines = parts.dropLast()
        // The remainder (may be empty or a partial line)
        let remainder = parts.last ?? ""
        
        for line in completeLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // Check if this is a traffic push JSON line
            if let trafficData = parseTrafficPushLine(trimmed) {
                onTrafficPush?(trafficData)
                // Don't add to logs to avoid clutter
            } else {
                logs.append("[\(Date().timeString)] \(trimmed)")
            }
        }
        
        // Keep the remainder for next read
        stdoutBuffer = remainder
    }

    /// Attempts to parse a stdout line as a traffic push JSON message.
    /// Returns [ProxyTrafficStats] if the line is a valid traffic push, nil otherwise.
    private func parseTrafficPushLine(_ line: String) -> [ProxyTrafficStats]? {
        // Quick check: must start with '{"type":"traffic"'
        guard line.hasPrefix(#"{"type":"traffic""#) else { return nil }

        guard let data = line.data(using: .utf8) else { return nil }

        let decoder = JSONDecoder()
        // Go outputs snake_case keys (bytes_in), Swift expects camelCase (bytesIn)
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let msg = try decoder.decode(TrafficPushMessage.self, from: data)
            return msg.proxies
        } catch {
            // Silently ignore malformed JSON; may be a partial/incomplete line
            return nil
        }
    }
}
