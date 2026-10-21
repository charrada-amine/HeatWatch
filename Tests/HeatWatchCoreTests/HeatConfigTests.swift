import XCTest
@testable import HeatWatchCore

final class HeatConfigTests: XCTestCase {
    func testDefaults() {
        XCTAssertEqual(HeatConfig.default.appCPUThreshold, 80)
    }
}
