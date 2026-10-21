import XCTest
@testable import HeatWatchCore

final class HeatAnalyzerTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_000_000)
    let spotifyPath = "/Applications/Spotify.app/Contents/Frameworks/Spotify Helper (Renderer).app/Contents/MacOS/Spotify Helper (Renderer)"

    func snapshot(at seconds: TimeInterval, spotifyCPU: Double, temp: Double = 55,
                  thermal: ProcessInfo.ThermalState = .nominal) -> Snapshot {
        Snapshot(date: start.addingTimeInterval(seconds), cpuTemperature: temp, batteryTemperature: 33,
                 apps: [makeApp(spotifyPath, cpu: spotifyCPU)], battery: nil, bootDate: nil, thermalState: thermal)
    }

    func testSustainedAppAlertsAfterThreeMinutes() {
        let analyzer = HeatAnalyzer()
        XCTAssertNil(analyzer.process(snapshot(at: 0, spotifyCPU: 130)))
        XCTAssertNil(analyzer.process(snapshot(at: 120, spotifyCPU: 130)))
        let alert = analyzer.process(snapshot(at: 180, spotifyCPU: 130))
        XCTAssertEqual(alert?.culprit.name, "Spotify")
        XCTAssertEqual(alert?.minutesAbove, 3)
        XCTAssertTrue(alert?.explanation.canQuit ?? false)
        XCTAssertEqual(alert?.subtitle, "Spotify : 130 % du processeur depuis 3 min")
        XCTAssertNotNil(analyzer.activeAlert)
        XCTAssertEqual(analyzer.level(for: snapshot(at: 180, spotifyCPU: 130)), .hot)

        // Cooldown: no second notification one minute later, but the alert stays active.
        XCTAssertNil(analyzer.process(snapshot(at: 240, spotifyCPU: 130)))
        XCTAssertEqual(analyzer.activeAlert?.minutesAbove, 4)
    }

    func testSnoozeSuppressesAlert() {
        let analyzer = HeatAnalyzer()
        analyzer.snooze("/Applications/Spotify.app", now: start)
        for t in stride(from: 0.0, through: 600, by: 60) {
            XCTAssertNil(analyzer.process(snapshot(at: t, spotifyCPU: 130)))
        }
        XCTAssertNil(analyzer.activeAlert)
    }

    func testDroppingBelowThresholdResetsCounter() {
        let analyzer = HeatAnalyzer()
        analyzer.process(snapshot(at: 0, spotifyCPU: 130))
        analyzer.process(snapshot(at: 150, spotifyCPU: 130))
        analyzer.process(snapshot(at: 155, spotifyCPU: 40))
        XCTAssertNil(analyzer.process(snapshot(at: 160, spotifyCPU: 130)))
        XCTAssertNil(analyzer.process(snapshot(at: 300, spotifyCPU: 130)))
        XCTAssertNotNil(analyzer.process(snapshot(at: 340, spotifyCPU: 130)))
    }

    func testSustainedTemperatureBlamesTopApp() {
        let analyzer = HeatAnalyzer()
        XCTAssertNil(analyzer.process(snapshot(at: 0, spotifyCPU: 50, temp: 90)))
        let alert = analyzer.process(snapshot(at: 120, spotifyCPU: 50, temp: 91))
        XCTAssertEqual(alert?.culprit.name, "Spotify")
        XCTAssertEqual(alert?.minutesAbove, 2)
    }

    func testSeriousThermalStateAlerts() {
        let analyzer = HeatAnalyzer()
        XCTAssertNotNil(analyzer.process(snapshot(at: 0, spotifyCPU: 20, thermal: .serious)))
    }

    func testLevels() {
        let analyzer = HeatAnalyzer()
        XCTAssertEqual(analyzer.level(for: snapshot(at: 0, spotifyCPU: 0, temp: 50)), .normal)
        XCTAssertEqual(analyzer.level(for: snapshot(at: 0, spotifyCPU: 0, temp: 75)), .warm)
        XCTAssertEqual(analyzer.level(for: snapshot(at: 0, spotifyCPU: 0, temp: 86)), .hot)
    }
}
