import Foundation
import Combine
import GoMarketMeAppleCoreKit

public struct GoMarketMeAffiliateMarketingData: Decodable, Sendable {
    public let campaign: Campaign
    public let affiliate: Affiliate
    public let saleDistribution: SaleDistribution
    public let affiliateCampaignCode: String
    public let deviceId: String
    public let offerCode: String?

    enum CodingKeys: String, CodingKey {
        case campaign
        case affiliate
        case saleDistribution = "sale_distribution"
        case affiliateCampaignCode = "affiliate_campaign_code"
        case deviceId = "device_id"
        case offerCode = "offer_code"
    }
}

public struct Campaign: Decodable, Sendable {
    public let id: String
    public let name: String
    public let status: String
    public let type: String
    public let publicLinkUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case type
        case publicLinkUrl = "public_link_url"
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

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case countryCode = "country_code"
        case instagramAccount = "instagram_account"
        case tiktokAccount = "tiktok_account"
        case xAccount = "x_account"
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
    public static let sdkVersion = "5.0.1"

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

    @available(*, deprecated, message: "syncAllTransactions() is no longer needed. GoMarketMe now syncs automatically after purchases.")
    public func syncAllTransactions() async {
        // No-op. Kept for source compatibility with SDK versions before 5.0.0.
    }

    @available(*, deprecated, message: "syncAllTransactions() is no longer needed. GoMarketMe now syncs automatically after purchases.")
    public static func syncAllTransactions() async {
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
