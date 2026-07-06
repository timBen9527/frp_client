import Foundation

struct TrafficStats: Identifiable {
    let id = UUID()
    let proxyName: String
    let proxyType: String
    var bytesIn: Int64 = 0
    var bytesOut: Int64 = 0
    var currentConnections: Int = 0
    var lastUpdated: Date = Date()
}

struct TrafficDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bytesIn: Int64
    let bytesOut: Int64
}
