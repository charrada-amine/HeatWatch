import os

enum Log {
    /// Read with: log show --last 10m --predicate 'subsystem == "com.charrada.heatwatch"'
    static let alerts = Logger(subsystem: "com.charrada.heatwatch", category: "alerts")
}
