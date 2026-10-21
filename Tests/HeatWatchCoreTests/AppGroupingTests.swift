import XCTest
@testable import HeatWatchCore

final class AppGroupingTests: XCTestCase {
    let spotifyRenderer = "/Applications/Spotify.app/Contents/Frameworks/Spotify Helper (Renderer).app/Contents/MacOS/Spotify Helper (Renderer)"
    let chromeRenderer = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/154.0.8037.57/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)"
    let windowServer = "/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer"

    func testSpotifyRenderer() {
        XCTAssertEqual(AppGrouping.appName(forExecutablePath: spotifyRenderer), "Spotify")
        XCTAssertEqual(AppGrouping.bundlePath(forExecutablePath: spotifyRenderer), "/Applications/Spotify.app")
    }

    func testChromeRenderer() {
        XCTAssertEqual(AppGrouping.appName(forExecutablePath: chromeRenderer), "Google Chrome")
        XCTAssertEqual(AppGrouping.bundlePath(forExecutablePath: chromeRenderer), "/Applications/Google Chrome.app")
    }

    func testWindowServer() {
        XCTAssertEqual(AppGrouping.appName(forExecutablePath: windowServer), "WindowServer")
        XCTAssertNil(AppGrouping.bundlePath(forExecutablePath: windowServer))
    }

    func testGroupSumsAndSorts() {
        let apps = AppGrouping.group([
            ProcessSample(pid: 1, cpu: 10, executablePath: "/Applications/Spotify.app/Contents/MacOS/Spotify"),
            ProcessSample(pid: 2, cpu: 120, executablePath: spotifyRenderer),
            ProcessSample(pid: 3, cpu: 30, executablePath: windowServer),
        ])
        XCTAssertEqual(apps.map(\.name), ["Spotify", "WindowServer"])
        XCTAssertEqual(apps[0].cpu, 130)
        XCTAssertEqual(apps[0].topProcess?.processName, "Spotify Helper (Renderer)")
    }
}
