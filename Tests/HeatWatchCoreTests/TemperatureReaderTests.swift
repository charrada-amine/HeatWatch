import XCTest
@testable import HeatWatchCore

final class TemperatureReaderTests: XCTestCase {
    func testCPUTemperatureUsesMaxTdie() {
        let readings = [
            SensorReading(name: "PMU tdie1", celsius: 46.5),
            SensorReading(name: "PMU tdie4", celsius: 49.2),
            SensorReading(name: "PMU tcal", celsius: 51.0),
            SensorReading(name: "PMU tdev1", celsius: -1.4),
            SensorReading(name: "gas gauge battery", celsius: 33.0),
            SensorReading(name: "NAND CH0 temp", celsius: 60.0),
        ]
        XCTAssertEqual(TemperatureReader.cpuTemperature(from: readings), 49.2)
        XCTAssertEqual(TemperatureReader.batteryTemperature(from: readings), 33.0)
    }

    func testIgnoresTcalAndInvalidTdie() {
        let readings = [
            SensorReading(name: "PMU tdie tcal", celsius: 99.0),
            SensorReading(name: "PMU tdie2", celsius: 0),
            SensorReading(name: "PMU tdie3", celsius: 47.0),
        ]
        XCTAssertEqual(TemperatureReader.cpuTemperature(from: readings), 47.0)
    }

    func testFallbackWithoutTdie() {
        let readings = [
            SensorReading(name: "gas gauge battery", celsius: 35.0),
            SensorReading(name: "PMU tdev2", celsius: 44.0),
            SensorReading(name: "PMU tcal", celsius: 55.0),
        ]
        XCTAssertEqual(TemperatureReader.cpuTemperature(from: readings), 44.0)
    }
}
