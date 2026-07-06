import Foundation

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let source: String
    let message: String
    let rawLine: String

    enum LogLevel: String, CaseIterable, Hashable {
        case info = "I"
        case warning = "W"
        case error = "E"
        case debug = "D"
        case trace = "T"
        case app = "A" // App-generated messages (not from frpc)

        var displayName: String {
            switch self {
            case .info: return "Info"
            case .warning: return "Warning"
            case .error: return "Error"
            case .debug: return "Debug"
            case .trace: return "Trace"
            case .app: return "App"
            }
        }

        var color: String {
            switch self {
            case .info: return "blue"
            case .warning: return "orange"
            case .error: return "red"
            case .debug: return "gray"
            case .trace: return "purple"
            case .app: return "teal"
            }
        }
    }

    static func parse(_ raw: String) -> LogEntry {
        // frpc log format: 2024-01-01 12:00:00.000 [I] [proxy.go:100] message
        let pattern = #"^\[(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2})\]\s*(.*)$"#
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to match app-prefixed logs: [timestamp] rest
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let tsRange = Range(match.range(at: 1), in: trimmed),
           let msgRange = Range(match.range(at: 2), in: trimmed) {

            let tsStr = String(trimmed[tsRange])
            let rest = String(trimmed[msgRange])

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let ts = formatter.date(from: tsStr) ?? Date()

            // Parse level from rest: [I] [source] message
            let levelPattern = #"^\[([IWEDT])\]\s*\[([^\]]+)\]\s*(.*)$"#
            if let levelRegex = try? NSRegularExpression(pattern: levelPattern),
               let levelMatch = levelRegex.firstMatch(in: rest, range: NSRange(rest.startIndex..., in: rest)),
               let lvlRange = Range(levelMatch.range(at: 1), in: rest),
               let srcRange = Range(levelMatch.range(at: 2), in: rest),
               let msgR = Range(levelMatch.range(at: 3), in: rest) {
                let lvlStr = String(rest[lvlRange])
                let level = LogLevel(rawValue: lvlStr) ?? .info
                let source = String(rest[srcRange])
                let message = String(rest[msgR])
                return LogEntry(timestamp: ts, level: level, source: source, message: message, rawLine: trimmed)
            }

            // No level marker - app message
            return LogEntry(timestamp: ts, level: .app, source: "app", message: rest, rawLine: trimmed)
        }

        // Fallback: no timestamp
        return LogEntry(timestamp: Date(), level: .app, source: "app", message: trimmed, rawLine: trimmed)
    }
}
