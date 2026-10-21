import CSensors

public struct SensorReading: Equatable {
    public let name: String
    public let celsius: Double

    public init(name: String, celsius: Double) {
        self.name = name
        self.celsius = celsius
    }
}

public enum TemperatureReader {
    public static func readAll() -> [SensorReading] {
        var buffer = [hw_sensor_reading](repeating: hw_sensor_reading(), count: 128)
        let count = Int(hw_read_temperatures(&buffer, Int32(buffer.count)))
        return buffer.prefix(count).map { reading in
            var raw = reading.name
            let name = withUnsafeBytes(of: &raw) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
            return SensorReading(name: name, celsius: reading.celsius)
        }
    }

    /// Max of the `tdie` sensors; falls back to the hottest valid non-battery sensor.
    public static func cpuTemperature(from readings: [SensorReading]) -> Double? {
        let valid = readings.filter { isValid($0) && !$0.name.lowercased().contains("tcal") }
        if let die = valid.filter({ $0.name.lowercased().contains("tdie") }).map(\.celsius).max() {
            return die
        }
        return valid.filter { !$0.name.lowercased().contains("battery") }.map(\.celsius).max()
    }

    public static func batteryTemperature(from readings: [SensorReading]) -> Double? {
        readings.filter { isValid($0) && $0.name.lowercased().contains("battery") }.map(\.celsius).max()
    }

    private static func isValid(_ reading: SensorReading) -> Bool {
        reading.celsius > 0 && reading.celsius < 130
    }
}
