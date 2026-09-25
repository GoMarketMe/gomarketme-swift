import XCTest
@testable import GoMarketMe

final class GoMarketMeTests: XCTestCase {
    func testSDKMetadata() throws {
        if #available(iOS 15.0, *) {
            XCTAssertEqual(GoMarketMe.sdkType, "Swift")
            XCTAssertEqual(GoMarketMe.sdkVersion, "6.0.0")
        }
    }

    func testReferralCodeIsOptionalInAttributionData() throws {
        let base = #"{"campaign":{"id":"c","name":"Campaign","status":"active","type":"public"},"affiliate":{"id":"a","first_name":"A","last_name":"B","country_code":"US","instagram_account":"","tiktok_account":"","x_account":""},"sale_distribution":{"platform_percentage":"10","affiliate_percentage":"20"},"affiliate_campaign_code":"campaign","device_id":"device"}"#
        let legacy = try JSONDecoder().decode(GoMarketMeAffiliateMarketingData.self, from: Data(base.utf8))
        XCTAssertNil(legacy.referralCode)

        let current = String(base.dropLast()) + ",\"referral_code\":\"FRIEND20\"}"
        let decoded = try JSONDecoder().decode(GoMarketMeAffiliateMarketingData.self, from: Data(current.utf8))
        XCTAssertEqual(decoded.referralCode, "FRIEND20")
    }
}
