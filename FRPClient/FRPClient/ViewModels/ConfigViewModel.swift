import Foundation
import Combine

@MainActor
final class ConfigViewModel: ObservableObject {

    @Published var config: FRPConfig
    @Published var saveMessage: String = ""
    @Published var showSaveAlert: Bool = false

    let processManager: FRPProcessManager
    private let configManager = ConfigManager.shared

    init(processManager: FRPProcessManager) {
        self.processManager = processManager
        self.config = configManager.loadConfig()
    }

    func addProxyRule() {
        let index = config.proxyRules.count + 1
        let rule = ProxyRule(
            name: "代理规则 \(index)",
            type: .tcp,
            localIP: "127.0.0.1",
            localPort: 8080,
            remotePort: 8080 + config.proxyRules.count
        )
        config.proxyRules.append(rule)
        saveConfig()
    }

    func removeProxyRule(at offsets: IndexSet) {
        config.proxyRules.remove(atOffsets: offsets)
    }

    func removeProxyRule(id: UUID) {
        config.proxyRules.removeAll { $0.id == id }
        saveConfig()
    }

    func duplicateProxyRule(_ rule: ProxyRule) {
        var newRule = rule
        newRule.id = UUID()
        newRule.name = "\(rule.name) (副本)"
        newRule.remotePort = rule.remotePort + 1
        config.proxyRules.append(newRule)
    }

    func moveProxyRule(from source: IndexSet, to destination: Int) {
        config.proxyRules.move(fromOffsets: source, toOffset: destination)
    }

    func saveConfig() {
        do {
            try configManager.saveConfig(config)
            try TOMLGenerator.writeToFile(from: config)
            saveMessage = "配置已保存"
            showSaveAlert = true
        } catch {
            saveMessage = "保存失败: \(error.localizedDescription)"
            showSaveAlert = true
        }
    }

    func applyAndRestart() {
        do {
            try configManager.saveConfig(config)
            try TOMLGenerator.writeToFile(from: config)
            processManager.restart()
            saveMessage = "配置已应用并重启服务"
            showSaveAlert = true
        } catch {
            saveMessage = "应用失败: \(error.localizedDescription)"
            showSaveAlert = true
        }
    }

    func validateConfig() -> [String] {
        var errors: [String] = []

        if config.serverAddr.isEmpty {
            errors.append("服务器地址不能为空")
        }

        if config.serverPort <= 0 || config.serverPort > 65535 {
            errors.append("服务器端口无效 (1-65535)")
        }

        var remotePorts = Set<Int>()
        for rule in config.proxyRules {
            if rule.name.isEmpty {
                errors.append("代理规则名称不能为空")
            }
            if rule.localPort <= 0 || rule.localPort > 65535 {
                errors.append("规则 '\(rule.name)' 的本地端口无效")
            }
            if rule.type == .tcp || rule.type == .udp {
                if remotePorts.contains(rule.remotePort) {
                    errors.append("规则 '\(rule.name)' 的远程端口 \(rule.remotePort) 冲突")
                }
                remotePorts.insert(rule.remotePort)
            }
        }

        return errors
    }
}
