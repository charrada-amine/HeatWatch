import XCTest
@testable import HeatWatchCore

final class ProcessSamplerTests: XCTestCase {
    func testParse() {
        let output = """
            1   0.3 /sbin/launchd
          482  38.9 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer
        12345 130.2 /Applications/Spotify.app/Contents/Frameworks/Spotify Helper (Renderer).app/Contents/MacOS/Spotify Helper (Renderer)
        garbage line
          abc  1.0 /bin/foo
        """
        let samples = ProcessSampler.parse(output)
        XCTAssertEqual(samples.count, 3)
        XCTAssertEqual(samples[0], ProcessSample(pid: 1, cpu: 0.3, executablePath: "/sbin/launchd"))
        XCTAssertEqual(samples[2].pid, 12345)
        XCTAssertEqual(samples[2].cpu, 130.2)
        XCTAssertEqual(samples[2].processName, "Spotify Helper (Renderer)")
        XCTAssertTrue(samples[2].executablePath.hasSuffix("MacOS/Spotify Helper (Renderer)"))
    }
}
