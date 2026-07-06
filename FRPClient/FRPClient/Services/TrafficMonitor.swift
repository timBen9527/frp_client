import Foundation
import Combine

/// Traffic statistics for a single proxy (matches the JSON returned by /api/traffic)
struct ProxyTrafficStats: Codable {
    let name: String
    let type: String
    let bytesIn: Int64
    let bytesOut: Int64
    let totalConns: Int64
    let activeConns: Int64
}

/// Top-level push message from frpc stdout: {"type":"traffic","proxies":[...],"timestamp":...}
struct TrafficPushMessage: Codable {
    let type: String
    let proxies: [ProxyTrafficStats]
    let timestamp: Int64
}

/// Monitors frpc traffic using stdout push (primary) with HTTP polling fallback.
@MainActor
final class TrafficMonitor: ObservableObject {

    @Published var proxyStats: [TrafficStats] = []
    @Published var dataPoints: [TrafficDataPoint] = []
    @Published var totalBytesIn: Int64 = 0
    @Published var totalBytesOut: Int64 = 0
    @Published var totalConnections: Int = 0
    @Published var isMonitoring: Bool = false
    @Published var errorMessage: String = ""
    @Published var lastFetchTime: Date?

    // Real-time speed (bytes per second)
    @Published var currentSpeedIn: Double = 0
    @Published var currentSpeedOut: Double = 0

    private var timer: Timer?
    private let maxDataPoints = 60
    private var adminPort: Int = 7400
    private var adminUser: String = ""
    private var adminPwd: String = ""

    // Previous traffic for speed calculation
    private var previousBytesIn: Int64 = 0
    private var previousBytesOut: Int64 = 0
    private var previousFetchTime: Date?

    // PID for diagnostics only
    private var frpcPID: Int32 = 0
    private var getPID: (() -> Int32)?

    // Push tracking
    private var lastPushTime: Date?

    // MARK: - Start / Stop

    func startMonitoring(config: FRPConfig, pidProvider: @escaping () -> Int32) {
        stopMonitoring()

        self.adminPort = config.adminPort > 0 ? config.adminPort : AppConstants.defaultAdminPort
        self.adminUser = config.adminUser
        self.adminPwd = config.adminPwd
        self.getPID = pidProvider
        self.frpcPID = pidProvider()

        isMonitoring = true
        errorMessage = ""
        previousBytesIn = 0
        previousBytesOut = 0
        previousFetchTime = nil
        lastPushTime = nil

        // Fetch initial data via HTTP (push may take a moment to start)
        fetchStats()

        // Polling as fallback every 5 seconds (push is primary at 1s)
        timer = Timer.scheduledTimer(withTimeInterval: AppConstants.dashboardRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchStats()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        currentSpeedIn = 0
        currentSpeedOut = 0
        getPID = nil
        frpcPID = 0
    }

    // MARK: - Push Data (from frpc stdout)

    /// Called by FRPProcessManager when a traffic JSON line is detected on stdout.
    /// This is the primary data source — real-time push at ~1s interval.
    /// Push data is always processed regardless of isMonitoring state,
    /// since stdout parsing works independently of the HTTP polling timer.
    func handlePushData(_ proxies: [ProxyTrafficStats]) {
        lastPushTime = Date()
        // Auto-enable monitoring when push data arrives (may not have been
        // explicitly started if user hasn't opened the Dashboard view yet)
        if !isMonitoring {
            isMonitoring = true
        }
        applyTrafficData(proxies)
    }

    // MARK: - HTTP Fallback

    private func fetchStats() {
        if let pidProvider = getPID {
            frpcPID = pidProvider()
        }

        // Skip HTTP poll if we received a push recently (< 3s)
        if let lastPush = lastPushTime, Date().timeIntervalSince(lastPush) < 3.0 {
            return
        }

        Task { [weak self] in
            guard let self = self else { return }
            let nativeTraffic = await self.fetchNativeTraffic()
            if let traffic = nativeTraffic {
                self.applyTrafficData(traffic)
            }
            // Note: don't show error when push hasn't started yet —
            // push data only flows after actual traffic occurs.
            // HTTP polling is just a fallback; silence is expected initially.
        }
    }

    // MARK: - Native /api/traffic

    private func fetchNativeTraffic() async -> [ProxyTrafficStats]? {
        guard let requestURL = URL(string: "http://127.0.0.1:\(adminPort)/api/traffic") else { return nil }

        do {
            var request = URLRequest(url: requestURL)
            request.timeoutInterval = 3
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            if !adminUser.isEmpty {
                let credentials = "\(adminUser):\(adminPwd)"
                if let credentialData = credentials.data(using: .utf8) {
                    let base64Credentials = credentialData.base64EncodedString()
                    request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
                }
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let traffic = try decoder.decode([ProxyTrafficStats].self, from: data)
            return traffic
        } catch {
            return nil
        }
    }

    // MARK: - Data Application

    private func applyTrafficData(_ proxyTrafficList: [ProxyTrafficStats]) {
        let now = Date()

        let totalIn = proxyTrafficList.reduce(0) { $0 + $1.bytesIn }
        let totalOut = proxyTrafficList.reduce(0) { $0 + $1.bytesOut }
        let totalConns = proxyTrafficList.reduce(0) { $0 + $1.activeConns }

        // Calculate speed with EMA smoothing
        if let prevTime = previousFetchTime, prevTime != .distantPast {
            let elapsed = now.timeIntervalSince(prevTime)
            if elapsed > 0 {
                let deltaIn = max(0, totalIn - previousBytesIn)
                let deltaOut = max(0, totalOut - previousBytesOut)
                let alpha = 0.3
                self.currentSpeedIn = self.currentSpeedIn * (1 - alpha) + (Double(deltaIn) / elapsed) * alpha
                self.currentSpeedOut = self.currentSpeedOut * (1 - alpha) + (Double(deltaOut) / elapsed) * alpha
            }
        }

        self.previousBytesIn = totalIn
        self.previousBytesOut = totalOut
        self.previousFetchTime = now
        self.totalBytesIn = totalIn
        self.totalBytesOut = totalOut
        self.totalConnections = Int(totalConns)

        // Per-proxy stats
        self.proxyStats = proxyTrafficList.map { traffic in
            TrafficStats(
                proxyName: traffic.name,
                proxyType: traffic.type,
                bytesIn: traffic.bytesIn,
                bytesOut: traffic.bytesOut,
                currentConnections: Int(traffic.activeConns),
                lastUpdated: now
            )
        }

        self.lastFetchTime = now
        self.errorMessage = ""

        // Data point for chart
        let point = TrafficDataPoint(timestamp: now, bytesIn: totalIn, bytesOut: totalOut)
        self.dataPoints.append(point)
        if self.dataPoints.count > self.maxDataPoints {
            self.dataPoints.removeFirst(self.dataPoints.count - self.maxDataPoints)
        }
    }

    // MARK: - Reset

    func reset() {
        proxyStats.removeAll()
        dataPoints.removeAll()
        totalBytesIn = 0
        totalBytesOut = 0
        totalConnections = 0
        currentSpeedIn = 0
        currentSpeedOut = 0
        errorMessage = ""
        lastFetchTime = nil
        previousBytesIn = 0
        previousBytesOut = 0
        previousFetchTime = nil
        lastPushTime = nil
    }
}
