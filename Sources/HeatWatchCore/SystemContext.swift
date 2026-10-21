import Foundation
import IOKit.ps

public struct BatteryState: Equatable {
    public let percent: Int
    public let isCharging: Bool
    public let onAC: Bool

    public init(percent: Int, isCharging: Bool, onAC: Bool) {
        self.percent = percent
        self.isCharging = isCharging
        self.onAC = onAC
    }
}

public enum SystemContext {
    public static func battery() -> BatteryState? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else { continue }
            let percent = desc[kIOPSCurrentCapacityKey] as? Int ?? -1
            let charging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let onAC = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return BatteryState(percent: percent, isCharging: charging, onAC: onAC)
        }
        return nil
    }

    /// Boot date, including sleep time (unlike ProcessInfo.systemUptime).
    public static func bootDate() -> Date? {
        var boot = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(boot.tv_sec))
    }

    public static func thermalState() -> ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }
}
