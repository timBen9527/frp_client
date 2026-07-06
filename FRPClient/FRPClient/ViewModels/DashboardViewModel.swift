import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {

    let trafficMonitor = TrafficMonitor()

    // Snapshot properties for the popover — updated only when the popover
    // explicitly refreshes, NOT on every traffic push.  This prevents the
    // StatusBarPopoverView from re-rendering at 1 Hz while it is shown.
    @Published var totalBytesIn: Int64 = 0
    @Published var totalBytesOut: Int64 = 0
    @Published var totalConnections: Int = 0
    @Published var currentSpeedIn: Double = 0
    @Published var currentSpeedOut: Double = 0

    var proxyStats: [TrafficStats] { trafficMonitor.proxyStats }
    var dataPoints: [TrafficDataPoint] { trafficMonitor.dataPoints }
    var isMonitoring: Bool { trafficMonitor.isMonitoring }
    var errorMessage: String { trafficMonitor.errorMessage }
    var lastFetchTime: Date? { trafficMonitor.lastFetchTime }

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward only the changes that the popover actually renders,
        // and throttle them to avoid 1 Hz re-renders.
        trafficMonitor.objectWillChange
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let tm = self.trafficMonitor
                self.totalBytesIn = tm.totalBytesIn
                self.totalBytesOut = tm.totalBytesOut
                self.totalConnections = tm.totalConnections
                self.currentSpeedIn = tm.currentSpeedIn
                self.currentSpeedOut = tm.currentSpeedOut
            }
            .store(in: &cancellables)
    }

    func startMonitoring(config: FRPConfig, pidProvider: @escaping () -> Int32) {
        trafficMonitor.startMonitoring(config: config, pidProvider: pidProvider)
    }

    func stopMonitoring() {
        trafficMonitor.stopMonitoring()
    }

    func reset() {
        trafficMonitor.reset()
    }
}
