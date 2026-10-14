import XCTest
import GoMarketMeAppleCoreKit
@testable import GoMarketMe

private final class InitializationURLProtocol: URLProtocol {
    static var mode = "unknown"
    static var initializationCalls = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let body: [String: Any]
        if request.url!.path.hasSuffix("sdk-initialization") {
            Self.initializationCalls += 1
            body = ["attribution_mode": Self.mode]
        } else {
            body = ["affiliate_campaign_code": "", "campaign": [:], "affiliate": [:], "sale_distribution": [:]]
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: body))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class GoMarketMeTests: XCTestCase {
    @MainActor
    func testInitializationFailureIsRetryableAndSavedModeRefreshes() async throws {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [InitializationURLProtocol.self]
        let core = GoMarketMeAppleCore(apiClient: GoMarketMeAppleApiClient(session: URLSession(configuration: sessionConfig)))
        let sdk = GoMarketMe(core: core)
        defer { sdk.stop() }
        let apiKey = UUID().uuidString
        InitializationURLProtocol.mode = "unknown"
        InitializationURLProtocol.initializationCalls = 0
        _ = await sdk.initialize(apiKey: apiKey)
        XCTAssertFalse(sdk.isInitialized)
        InitializationURLProtocol.mode = "ReferralCodesOnly"
        _ = await sdk.initialize(apiKey: apiKey)
        XCTAssertTrue(sdk.isInitialized)
        XCTAssertTrue((sdk.attributionMode == "ReferralCodesOnly"))
        XCTAssertNil(sdk.affiliateMarketingData)
        let reference = sdk.appInstallRef
        XCTAssertNotNil(reference)
        InitializationURLProtocol.mode = "LinksOnly"
        _ = await sdk.initialize(apiKey: apiKey)
        XCTAssertFalse((sdk.attributionMode == "ReferralCodesOnly"))
        XCTAssertEqual(sdk.appInstallRef, reference)
        XCTAssertEqual(InitializationURLProtocol.initializationCalls, 3)
    }
    func testInstallReferenceIgnoresReturnedLegacyDeviceID() throws {
        let json = #"{"campaign":{"id":"c","name":"Campaign","status":"Running","type":"Public"},"affiliate":{"id":"a","first_name":"A","last_name":"B","country_code":"US","instagram_account":"","tiktok_account":"","x_account":""},"sale_distribution":{"platform_percentage":"10","affiliate_percentage":"20"},"affiliate_campaign_code":"campaign","app_install_ref":"install-reference","device_id":"legacy"}"#
        let data = try JSONDecoder().decode(GoMarketMeAffiliateMarketingData.self, from: Data(json.utf8))
        XCTAssertEqual(data.appInstallRef, "install-reference")
        XCTAssertEqual(data.deviceId, "")
        let withoutDeviceID = json.replacingOccurrences(of: ",\"device_id\":\"legacy\"", with: "")
        XCTAssertNoThrow(try JSONDecoder().decode(GoMarketMeAffiliateMarketingData.self, from: Data(withoutDeviceID.utf8)))
    }
    func testSDKMetadata() throws {
        if #available(iOS 15.0, *) {
            XCTAssertEqual(GoMarketMe.sdkType, "Swift")
            XCTAssertEqual(GoMarketMe.sdkVersion, "6.0.2")
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
