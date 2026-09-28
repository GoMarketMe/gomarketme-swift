import XCTest
@testable import GoMarketMe

final class GoMarketMeTests: XCTestCase {
    func testSDKMetadata() throws {
        if #available(iOS 15.0, *) {
            XCTAssertEqual(GoMarketMe.sdkType, "Swift")
            XCTAssertEqual(GoMarketMe.sdkVersion, "6.0.1")
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

    func testMetadataDefaultsToEmptyAndDecodesAtEveryScope() throws {
        let legacy = #"{"campaign":{"id":"c","name":"Campaign","status":"active","type":"public"},"affiliate":{"id":"a","first_name":"A","last_name":"B","country_code":"US","instagram_account":"","tiktok_account":"","x_account":""},"sale_distribution":{"platform_percentage":"10","affiliate_percentage":"20"},"affiliate_campaign_code":"campaign","device_id":"device"}"#
        let legacyData = try JSONDecoder().decode(GoMarketMeAffiliateMarketingData.self, from: Data(legacy.utf8))
        XCTAssertTrue(legacyData.campaign.metadata.isEmpty)
        XCTAssertTrue(legacyData.affiliate.metadata.isEmpty)
        XCTAssertTrue(legacyData.affiliateCampaign.metadata.isEmpty)

        let current = #"{"campaign":{"id":"c","name":"Campaign","status":"active","type":"public","metadata":{"paywall_variant":"creator-offer"}},"affiliate":{"id":"a","first_name":"A","last_name":"B","country_code":"US","instagram_account":"","tiktok_account":"","x_account":"","metadata":{"profile_image_url":"https://example.com/jake.jpg"}},"affiliate_campaign":{"metadata":{"offers":{"ios":{"monthly":{"code":"MONTHLY10"}}}}},"sale_distribution":{"platform_percentage":"10","affiliate_percentage":"20"},"affiliate_campaign_code":"campaign","device_id":"device"}"#
        let decoded = try JSONDecoder().decode(GoMarketMeAffiliateMarketingData.self, from: Data(current.utf8))
        XCTAssertEqual(decoded.campaign.metadata["paywall_variant"], .string("creator-offer"))
        XCTAssertEqual(decoded.affiliate.metadata["profile_image_url"], .string("https://example.com/jake.jpg"))
        XCTAssertEqual(
            decoded.affiliateCampaign.metadata["offers"],
            .object(["ios": .object(["monthly": .object(["code": .string("MONTHLY10")])])])
        )
        XCTAssertEqual(
            decoded.affiliateCampaign.metadata["offers"]?["ios"]?["monthly"]?["code"]?.stringValue,
            "MONTHLY10"
        )
    }

    func testReferralCodeErrorCarriesActionableDetails() {
        let error = GoMarketMeReferralCodeError(
            code: .invalidCode,
            rawCode: "invalid_code",
            statusCode: 422,
            message: "Referral code is invalid."
        )

        XCTAssertEqual(error.code, .invalidCode)
        XCTAssertEqual(error.rawCode, "invalid_code")
        XCTAssertEqual(error.statusCode, 422)
        XCTAssertFalse(error.isRetryable)
        XCTAssertEqual(error.localizedDescription, "Referral code is invalid.")
    }
}
