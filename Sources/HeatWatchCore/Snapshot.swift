import Foundation

/// One complete measurement.
public struct Snapshot {
    public let date: Date
    public let cpuTemperature: Double?
    public let batteryTemperature: Double?
    /// Sorted by decreasing CPU.
    public let apps: [AppUsage]
    public let battery: BatteryState?
    public let bootDate: Date?
    public let thermalState: ProcessInfo.ThermalState
    public let sensorCount: Int
    public let processCount: Int

    public init(date: Date, cpuTemperature: Double?, batteryTemperature: Double?, apps: [AppUsage],
                battery: BatteryState?, bootDate: Date?, thermalState: ProcessInfo.ThermalState,
                sensorCount: Int = 0, processCount: Int = 0) {
        self.date = date
        self.cpuTemperature = cpuTemperature
        self.batteryTemperature = batteryTemperature
        self.apps = apps
        self.battery = battery
        self.bootDate = bootDate
        self.thermalState = thermalState
        self.sensorCount = sensorCount
        self.processCount = processCount
    }

    public var daysSinceBoot: Double? {
        bootDate.map { date.timeIntervalSince($0) / 86_400 }
    }

    /// Takes a full measurement. Blocking (runs `ps`): call it off the main thread,
    /// and never from two threads at once (the sensor reader is not thread-safe).
    public static func capture(date: Date = Date()) -> Snapshot {
        let readings = TemperatureReader.readAll()
        let samples = ProcessSampler.sample()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let filtered = samples.filter { sample in
            sample.pid != ownPID && sample.processName != "ps"
                && AppGrouping.appName(forExecutablePath: sample.executablePath) != "HeatWatch"
        }
        return Snapshot(
            date: date,
            cpuTemperature: TemperatureReader.cpuTemperature(from: readings),
            batteryTemperature: TemperatureReader.batteryTemperature(from: readings),
            apps: AppGrouping.group(filtered),
            battery: SystemContext.battery(),
            bootDate: SystemContext.bootDate(),
            thermalState: SystemContext.thermalState(),
            sensorCount: readings.count,
            processCount: samples.count
        )
    }
}
