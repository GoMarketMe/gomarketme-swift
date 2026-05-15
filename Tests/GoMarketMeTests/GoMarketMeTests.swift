import XCTest
@testable import GoMarketMe

final class GoMarketMeTests: XCTestCase {
    func testSDKMetadata() throws {
        if #available(iOS 15.0, *) {
            XCTAssertEqual(GoMarketMe.sdkType, "Swift")
            XCTAssertEqual(GoMarketMe.sdkVersion, "5.0.4")
        }
    }
}
