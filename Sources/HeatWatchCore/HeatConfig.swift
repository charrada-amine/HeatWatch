import Foundation

/// All thresholds used by the analyzer and the UI.
/// Temperatures calibrated on a fanless MacBook Air M2 (21/10/2026): 45–53 °C idle,
/// ~78 °C plateau after 3 min with 4 busy cores (see README).
public struct HeatConfig {
    public var sampleInterval: TimeInterval = 5
    public var appCPUThreshold: Double = 80
    public var appSustained: TimeInterval = 180
    public var tempWarm: Double = 65
    public var tempHot: Double = 80
    public var tempAlert: Double = 80
    public var tempSustained: TimeInterval = 120
    public var alertCooldown: TimeInterval = 900
    public var snoozeDuration: TimeInterval = 3600

    public init() {}

    public static let `default` = HeatConfig()
}
