import XCTest
@testable import HeatWatchCore

func makeApp(_ path: String, cpu: Double) -> AppUsage {
    AppGrouping.group([ProcessSample(pid: 42, cpu: cpu, executablePath: path)])[0]
}

final class ExplainerTests: XCTestCase {
    func testSpotifyRenderer() {
        let app = makeApp("/Applications/Spotify.app/Contents/Frameworks/Spotify Helper (Renderer).app/Contents/MacOS/Spotify Helper (Renderer)", cpu: 130)
        let explanation = Explainer.explain(app, minutes: 4)
        XCTAssertTrue(explanation.reason.contains("interface de Spotify"))
        XCTAssertTrue(explanation.canQuit)
    }

    func testChromeRenderer() {
        let app = makeApp("/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/154.0.8037.57/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)", cpu: 110)
        XCTAssertTrue(Explainer.explain(app, minutes: 3).reason.contains("onglet"))
    }

    func testSpotlight() {
        let app = makeApp("/System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Versions/A/Support/mds_stores", cpu: 90)
        let explanation = Explainer.explain(app, minutes: 3)
        XCTAssertTrue(explanation.reason.contains("Spotlight"))
        XCTAssertFalse(explanation.canQuit)
    }

    func testWindowServer() {
        let app = makeApp("/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer", cpu: 90)
        XCTAssertFalse(Explainer.explain(app, minutes: 3).canQuit)
    }

    func testFallbackAndBareExecutable() {
        let app = makeApp("/usr/bin/yes", cpu: 99.6)
        let explanation = Explainer.explain(app, minutes: 3)
        XCTAssertEqual(explanation.reason, "yes utilise 100 % du processeur depuis 3 min.")
        XCTAssertFalse(explanation.canQuit)
    }

    func testContextLines() {
        let now = Date()
        let snapshot = Snapshot(date: now, cpuTemperature: 60, batteryTemperature: 33, apps: [],
                                battery: BatteryState(percent: 30, isCharging: true, onAC: true),
                                bootDate: now.addingTimeInterval(-20 * 86_400), thermalState: .serious)
        let lines = Explainer.contextLines(for: snapshot)
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("30 %"))
        XCTAssertTrue(lines[1].contains("20 jours"))
    }
}
