import SwiftUI

struct LogsView: View {
    @ObservedObject var processManager: FRPProcessManager
    @State private var selectedLevel: LogEntry.LogLevel? = nil
    @State private var searchText: String = ""
    @State private var autoScroll: Bool = true

    private var parsedLogs: [LogEntry] {
        processManager.logs.map { LogEntry.parse($0) }
    }

    private var filteredLogs: [LogEntry] {
        var logs = parsedLogs
        if let level = selectedLevel {
            logs = logs.filter { $0.level == level }
        }
        if !searchText.isEmpty {
            logs = logs.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.source.localizedCaseInsensitiveContains(searchText) ||
                $0.rawLine.localizedCaseInsensitiveContains(searchText)
            }
        }
        return logs
    }

    private var levelCounts: [LogEntry.LogLevel: Int] {
        let counts = Dictionary(grouping: parsedLogs, by: { $0.level }).mapValues { $0.count }
        return counts
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider()

            // Log list
            if filteredLogs.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredLogs.enumerated()), id: \.element.id) { index, entry in
                                logRow(entry, isLast: index == filteredLogs.count - 1)
                                    .id(index)
                            }
                        }
                    }
                    .onChange(of: filteredLogs.count) { _ in
                        if autoScroll, let last = filteredLogs.indices.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 10) {
            HStack {
                SectionHeader("运行日志")
                Spacer()
                HStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 12))
                            .foregroundColor(autoScroll ? .accentColor : .secondary)
                        Text("自动滚动")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(autoScroll ? Color.accentColor.opacity(0.1) : Color.clear)
                    )
                    .onTapGesture { autoScroll.toggle() }

                    Button {
                        processManager.clearLogs()
                    } label: {
                        Label("清空", systemImage: "trash")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .buttonStyle(.bordered)
                    
                    Button {
                        exportLogs()
                    } label: {
                        Label("导出", systemImage: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .buttonStyle(.bordered)
                }
            }

            // Level filter chips
            HStack(spacing: 6) {
                levelChip(nil, label: "全部", count: processManager.logs.count)
                levelChip(.info, label: "信息", count: levelCounts[.info] ?? 0)
                levelChip(.warning, label: "警告", count: levelCounts[.warning] ?? 0)
                levelChip(.error, label: "错误", count: levelCounts[.error] ?? 0)
                levelChip(.app, label: "应用", count: levelCounts[.app] ?? 0)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("搜索日志...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .frame(width: 180)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.textBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.primary.opacity(0.1), Color.accentColor.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
            }
        }
    }

    private func levelChip(_ level: LogEntry.LogLevel?, label: String, count: Int) -> some View {
        let isSelected = selectedLevel == level
        let chipColor = level != nil ? levelColor(level!) : Color.accentColor
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedLevel = level
            }
        } label: {
            HStack(spacing: 4) {
                if let level = level {
                    Circle()
                        .fill(levelColor(level))
                        .frame(width: 5, height: 5)
                }
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(isSelected ? chipColor : .secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isSelected ? chipColor.opacity(0.15) : Color.secondary.opacity(0.1))
                        )
                }
            }
            .foregroundColor(isSelected ? chipColor : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? chipColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isSelected ? chipColor.opacity(0.25) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Log Row

    private func logRow(_ entry: LogEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Level indicator
            levelDot(entry.level)
                .frame(width: 14)
                .padding(.top, 7)

            // Timestamp
            Text(entry.timestamp.timeString)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
                .frame(width: 65, alignment: .leading)
                .padding(.top, 1)

            // Source
            Text(entry.source)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(levelColor(entry.level).opacity(0.8))
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)
                .padding(.top, 1)

            // Message
            Text(entry.message)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            entry.level == .error ? Color.red.opacity(0.04) :
            entry.level == .warning ? Color.orange.opacity(0.03) :
            Color.clear
        )
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 0.5)
                    .padding(.leading, 14)
            }
        }
    }

    private func levelDot(_ level: LogEntry.LogLevel) -> some View {
        Circle()
            .fill(levelColor(level))
            .frame(width: 6, height: 6)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(0.06))
                    .frame(width: 64, height: 64)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.accentColor.opacity(0.5))
            }
            Text("暂无日志")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            if selectedLevel != nil || !searchText.isEmpty {
                Text("当前筛选条件下没有匹配的日志")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
                Button("清除筛选") {
                    selectedLevel = nil
                    searchText = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
            } else if !processManager.isRunning {
                Text("启动 frpc 服务后将在此显示运行日志")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func levelColor(_ level: LogEntry.LogLevel) -> Color {
        switch level {
        case .info: return .accentColor
        case .warning: return .orange
        case .error: return .red
        case .debug: return .gray
        case .trace: return .purple
        case .app: return .teal
        }
    }

    private func exportLogs() {
        let content = processManager.logs.joined(separator: "\n")
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "frpc_\(Date().timeString).log"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
