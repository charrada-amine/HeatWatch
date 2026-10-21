import Foundation

/// All thresholds used by the analyzer and the UI.
public struct HeatConfig {
    public var sampleInterval: TimeInterval = 5
    public var appCPUThreshold: Double = 80
    public var appSustained: TimeInterval = 180
    public var tempWarm: Double = 70
    public var tempHot: Double = 85
    public var tempAlert: Double = 85
    public var tempSustained: TimeInterval = 120
    public var alertCooldown: TimeInterval = 900
    public var snoozeDuration: TimeInterval = 3600

    public init() {}

    public static let `default` = HeatConfig()
}
