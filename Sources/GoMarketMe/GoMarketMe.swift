import Foundation
import Combine
import GoMarketMeAppleCoreKit

public typealias GoMarketMeMetadata = [String: GoMarketMeJSONValue]

public enum GoMarketMeReferralCodeErrorCode: String, Sendable {
    case invalidCode = "invalid_code"
    case expiredCode = "expired_code"
    case inactiveCode = "inactive_code"
    case invalidResponse = "invalid_response"
    case requestFailed = "request_failed"
    case networkError = "network_error"
    case timeout
    case notInitialized = "not_initialized"
    case unknown
}

public struct GoMarketMeReferralCodeError: LocalizedError, Sendable {
    public let code: GoMarketMeReferralCodeErrorCode
    public let rawCode: String
    public let statusCode: Int?
    public let isRetryable: Bool
    public let message: String

    public var errorDescription: String? { message }

    public init(
        code: GoMarketMeReferralCodeErrorCode,
        rawCode: String,
        statusCode: Int? = nil,
        isRetryable: Bool = false,
        message: String
    ) {
        self.code = code
        self.rawCode = rawCode
        self.statusCode = statusCode
        self.isRetryable = isRetryable
        self.message = message
    }
}

public enum GoMarketMeJSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: GoMarketMeJSONValue])
    case array([GoMarketMeJSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: GoMarketMeJSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([GoMarketMeJSONValue].self) { self = .array(value) }
        else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public subscript(key: String) -> GoMarketMeJSONValue? {
        guard case .object(let value) = self else { return nil }
        return value[key]
    }

    public var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    public var numberValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    public var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    public var objectValue: [String: GoMarketMeJSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    public var arrayValue: [GoMarketMeJSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }
}

public struct GoMarketMeAffiliateMarketingData: Decodable, Sendable {
    public let campaign: Campaign
    public let affiliate: Affiliate
    public let affiliateCampaign: AffiliateCampaign
    public let saleDistribution: SaleDistribution
    public let affiliateCampaignCode: String
    public let deviceId: String
    public let offerCode: String?
    public let referralCode: String?

    enum CodingKeys: String, CodingKey {
        case campaign
        case affiliate
        case affiliateCampaign = "affiliate_campaign"
        case saleDistribution = "sale_distribution"
        case affiliateCampaignCode = "affiliate_campaign_code"
        case deviceId = "device_id"
        case offerCode = "offer_code"
        case referralCode = "referral_code"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        campaign = try container.decode(Campaign.self, forKey: .campaign)
        affiliate = try container.decode(Affiliate.self, forKey: .affiliate)
        affiliateCampaign = try container.decodeIfPresent(AffiliateCampaign.self, forKey: .affiliateCampaign) ?? AffiliateCampaign()
        saleDistribution = try container.decode(SaleDistribution.self, forKey: .saleDistribution)
        affiliateCampaignCode = try container.decode(String.self, forKey: .affiliateCampaignCode)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        offerCode = try container.decodeIfPresent(String.self, forKey: .offerCode)
        referralCode = try container.decodeIfPresent(String.self, forKey: .referralCode)
    }
}

public struct Campaign: Decodable, Sendable {
    public let id: String
    public let name: String
    public let status: String
    public let type: String
    public let publicLinkUrl: String?
    public let metadata: GoMarketMeMetadata

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case type
        case publicLinkUrl = "public_link_url"
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(String.self, forKey: .status)
        type = try container.decode(String.self, forKey: .type)
        publicLinkUrl = try container.decodeIfPresent(String.self, forKey: .publicLinkUrl)
        metadata = try container.decodeIfPresent(GoMarketMeMetadata.self, forKey: .metadata) ?? [:]
    }
}

public struct Affiliate: Decodable, Sendable {
    public let id: String
    public let firstName: String
    public let lastName: String
    public let countryCode: String
    public let instagramAccount: String
    public let tiktokAccount: String
    public let xAccount: String
    public let metadata: GoMarketMeMetadata

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case countryCode = "country_code"
        case instagramAccount = "instagram_account"
        case tiktokAccount = "tiktok_account"
        case xAccount = "x_account"
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        countryCode = try container.decode(String.self, forKey: .countryCode)
        instagramAccount = try container.decode(String.self, forKey: .instagramAccount)
        tiktokAccount = try container.decode(String.self, forKey: .tiktokAccount)
        xAccount = try container.decode(String.self, forKey: .xAccount)
        metadata = try container.decodeIfPresent(GoMarketMeMetadata.self, forKey: .metadata) ?? [:]
    }
}

public struct AffiliateCampaign: Decodable, Sendable {
    public let metadata: GoMarketMeMetadata

    enum CodingKeys: String, CodingKey { case metadata }

    public init(metadata: GoMarketMeMetadata = [:]) {
        self.metadata = metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metadata = try container.decodeIfPresent(GoMarketMeMetadata.self, forKey: .metadata) ?? [:]
    }
}


public struct GoMarketMeTransactionSyncResult: Sendable {
    public let fetchedCount: Int
    public let sentCount: Int
    public let failedCount: Int
    public let success: Bool

    public init(fetchedCount: Int, sentCount: Int, failedCount: Int, success: Bool) {
        self.fetchedCount = fetchedCount
        self.sentCount = sentCount
        self.failedCount = failedCount
        self.success = success
    }

    init(_ result: GoMarketMeAppleCurrentPurchaseSyncResult) {
        self.init(
            fetchedCount: result.fetchedCount,
            sentCount: result.sentCount,
            failedCount: result.failedCount,
            success: result.success
        )
    }
}

public struct SaleDistribution: Decodable, Sendable {
    public let platformPercentage: String
    public let affiliatePercentage: String

    enum CodingKeys: String, CodingKey {
        case platformPercentage = "platform_percentage"
        case affiliatePercentage = "affiliate_percentage"
    }
}

@available(iOS 15.0, *)
public final class GoMarketMe: ObservableObject, @unchecked Sendable {
    public static let shared = GoMarketMe()

    public static let sdkType = "Swift"
    public static let sdkVersion = "6.0.1"

    @Published public private(set) var affiliateMarketingData: GoMarketMeAffiliateMarketingData?
    @Published public private(set) var isInitialized = false
    @Published public private(set) var isInitializing = false

    public var onPurchase: ((GoMarketMeApplePurchaseEvent) -> Void)? {
        didSet {
            core.onPurchase = onPurchase
        }
    }

    public var onError: ((Error) -> Void)? {
        didSet {
            core.onError = onError
        }
    }

    private let core: GoMarketMeAppleCore
    private let stateQueue = DispatchQueue(label: "co.gomarketme.swift.sdk")
    private var hasStartedInitialization = false
    private var apiKey: String?

    public init(core: GoMarketMeAppleCore = GoMarketMeAppleCore()) {
        self.core = core
        self.core.onError = { error in
            debugPrint("[GoMarketMe Swift] core error: \(error.localizedDescription)")
        }
    }

    public func initialize(apiKey: String) {
        Task {
            await initialize(apiKey: apiKey)
        }
    }

    @discardableResult
    public func initialize(apiKey: String) async -> GoMarketMeAffiliateMarketingData? {
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedApiKey.isEmpty else {
            debugPrint("[GoMarketMe Swift] Initialization skipped because apiKey is empty.")
            await setInitializing(false)
            return nil
        }

        let shouldStart = stateQueue.sync { () -> Bool in
            if hasStartedInitialization {
                return false
            }

            hasStartedInitialization = true
            self.apiKey = trimmedApiKey
            return true
        }

        guard shouldStart else {
            debugPrint("[GoMarketMe Swift] Initialization skipped because SDK is already initialized or initializing.")
            return affiliateMarketingData
        }

        await setInitializing(true)

        let initialConfiguration = GoMarketMeAppleCoreConfiguration(
            apiKey: trimmedApiKey,
            sdkType: Self.sdkType,
            sdkVersion: Self.sdkVersion,
            isProduction: isProductionBuild()
        )

        core.onPurchase = onPurchase
        core.onError = onError ?? { error in
            debugPrint("[GoMarketMe Swift] core error: \(error.localizedDescription)")
        }

        let prepared = await core.prepareAttribution(configuration: initialConfiguration)
        core.configure(prepared.configuration)
        core.start()

        let decodedAffiliateData = Self.decodeAffiliateMarketingData(
            prepared.affiliateMarketingData
        )

        await MainActor.run {
            self.affiliateMarketingData = decodedAffiliateData
            self.isInitialized = true
            self.isInitializing = false
        }

        debugPrint("[GoMarketMe Swift] initialized")

        return decodedAffiliateData
    }

    /// Returns the applied affiliate data, or nil when the user dismisses the sheet.
    @MainActor
    public func showReferralCodeSheet(showTrigger: Bool = false) async throws -> GoMarketMeAffiliateMarketingData? {
        guard isInitialized else { throw NSError(domain: "GoMarketMe", code: 1, userInfo: [NSLocalizedDescriptionKey: "Initialize GoMarketMe first."]) }
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    try await core.showReferralCodeSheet(showTrigger: showTrigger) { [weak self] response in
                        let data = Self.decodeAffiliateMarketingData(response)
                        if response != nil { self?.affiliateMarketingData = data }
                        continuation.resume(returning: data)
                    }
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    /// Loads the complete remotely configured referral-code appearance.
    public func referralCodeSettings() async throws -> [String: Any] {
        guard isInitialized else {
            throw NSError(
                domain: "GoMarketMe",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Initialize GoMarketMe first."]
            )
        }
        return try await core.referralCodeSettings()
    }

    /// Redeems a referral code from an app-owned UI and returns the resulting attribution data.
    @discardableResult
    public func redeemReferralCode(_ code: String) async throws -> GoMarketMeAffiliateMarketingData {
        guard isInitialized else {
            throw GoMarketMeReferralCodeError(
                code: .notInitialized,
                rawCode: GoMarketMeReferralCodeErrorCode.notInitialized.rawValue,
                message: "Initialize GoMarketMe before redeeming a referral code."
            )
        }
        let response: [String: Any]
        do {
            response = try await core.redeemReferralCode(code)
        } catch let error as GoMarketMeReferralError {
            throw Self.referralCodeError(
                rawCode: error.code,
                statusCode: error.statusCode > 0 ? error.statusCode : nil,
                message: error.localizedDescription
            )
        } catch let error as URLError {
            let rawCode = error.code == .timedOut ? "timeout" : "network_error"
            throw Self.referralCodeError(
                rawCode: rawCode,
                statusCode: nil,
                message: error.localizedDescription
            )
        } catch {
            throw Self.referralCodeError(
                rawCode: "request_failed",
                statusCode: nil,
                message: error.localizedDescription
            )
        }
        guard let data = Self.decodeAffiliateMarketingData(response) else {
            throw GoMarketMeReferralCodeError(
                code: .invalidResponse,
                rawCode: GoMarketMeReferralCodeErrorCode.invalidResponse.rawValue,
                message: "GoMarketMe returned an invalid referral-code response."
            )
        }
        await MainActor.run { self.affiliateMarketingData = data }
        return data
    }

    public func stop() {
        core.stop()

        stateQueue.sync {
            self.hasStartedInitialization = false
            self.apiKey = nil
        }

        Task { @MainActor in
            self.isInitialized = false
            self.isInitializing = false
            self.affiliateMarketingData = nil
        }
    }

    public func syncAllTransactions() async -> GoMarketMeTransactionSyncResult {
        guard isInitialized else {
            debugPrint("[GoMarketMe Swift] Transaction sync skipped because SDK is not initialized.")
            return GoMarketMeTransactionSyncResult(
                fetchedCount: 0,
                sentCount: 0,
                failedCount: 0,
                success: false
            )
        }

        let result = await core.syncAllTransactions()
        return GoMarketMeTransactionSyncResult(result)
    }

    public static func syncAllTransactions() async -> GoMarketMeTransactionSyncResult {
        await shared.syncAllTransactions()
    }

    public func debugCurrentPurchases() async throws -> [[String: Any]] {
        try await core.currentPurchases().map { $0.toDictionary() }
    }

    public func debugAllTransactions() async -> [[String: Any]] {
        await core.debugAllTransactions()
    }

    private static func decodeAffiliateMarketingData(
        _ dictionary: [String: Any]?
    ) -> GoMarketMeAffiliateMarketingData? {
        guard let dictionary, !dictionary.isEmpty else {
            return nil
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            return try JSONDecoder().decode(GoMarketMeAffiliateMarketingData.self, from: data)
        } catch {
            debugPrint("[GoMarketMe Swift] affiliate data decoding failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func referralCodeError(
        rawCode: String,
        statusCode: Int?,
        message: String
    ) -> GoMarketMeReferralCodeError {
        let code = GoMarketMeReferralCodeErrorCode(rawValue: rawCode) ?? .unknown
        let isRetryable = rawCode == "network_error" || rawCode == "timeout" ||
            statusCode == 408 || statusCode == 425 || statusCode == 429 ||
            (statusCode.map { $0 >= 500 } ?? false)
        return GoMarketMeReferralCodeError(
            code: code,
            rawCode: rawCode,
            statusCode: statusCode,
            isRetryable: isRetryable,
            message: message
        )
    }

    @MainActor
    private func setInitializing(_ value: Bool) {
        isInitializing = value
    }

    private func isProductionBuild() -> Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}
