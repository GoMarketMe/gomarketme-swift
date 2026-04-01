import Foundation
import UIKit
import StoreKit

public struct GoMarketMeAffiliateMarketingData: Decodable {
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

public struct Campaign: Decodable {
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

public struct Affiliate: Decodable {
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

public struct SaleDistribution: Decodable {
    public let platformPercentage: String
    public let affiliatePercentage: String

    enum CodingKeys: String, CodingKey {
        case platformPercentage = "platform_percentage"
        case affiliatePercentage = "affiliate_percentage"
    }
}

@MainActor
public class GoMarketMe: NSObject, ObservableObject {

    public static let shared = GoMarketMe()
    private let sdkInitializedKey = "GOMARKETME_SDK_INITIALIZED"
    private let sdkType = "Swift"
    private let sdkVersion = "3.0.1"
    private var apiKey: String = ""
    private let sdkInitializationUrl = URL(string: "https://4v9008q1a5.execute-api.us-west-2.amazonaws.com/prod/v1/sdk-initialization")!
    private let systemInfoUrl = URL(string: "https://4v9008q1a5.execute-api.us-west-2.amazonaws.com/prod/v1/mobile/system-info")!
    private let eventUrl = URL(string: "https://4v9008q1a5.execute-api.us-west-2.amazonaws.com/prod/v1/event")!
    private var affiliateCampaignCode: String = ""
    private var deviceId: String = ""
    private var packageName = ""
    private var updatesTask: Task<Void, Never>?

    @Published public var affiliateMarketingData: GoMarketMeAffiliateMarketingData?

    private override init() {
        super.init()
    }

    public func initialize(apiKey: String) {
        self.apiKey = apiKey

        Task {
            do {
                if !isSDKInitialized() {
                    try await postSDKInitialization(apiKey: apiKey)
                }

                let systemInfo = getSystemInfo()
                packageName = Bundle.main.bundleIdentifier ?? "Unknown"

                if let deviceInfo = systemInfo["device_info"] as? [String: Any],
                   let identifierForVendor = deviceInfo["identifierForVendor"] as? String {
                    deviceId = identifierForVendor
                }

                let data = await postSystemInfo(data: systemInfo, apiKey: apiKey)
                self.affiliateMarketingData = data
                if let data = data {
                    self.affiliateCampaignCode = data.affiliateCampaignCode
                }
                listenForTransactions()
                await processAllTransactions()
            } catch {
                print("Initialization failed with error: \(error)")
                affiliateMarketingData = nil
            }
        }
    }

    private func listenForTransactions() {
        updatesTask = Task.detached(priority: .background) {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    let products = await self.fetchProducts(for: [transaction.productID])
                    await self.sendDetails(transactions: [result.jwsRepresentation], products: products)
                    await transaction.finish()
                case .unverified(let transaction, _):
                    let products = await self.fetchProducts(for: [transaction.productID])
                    await self.sendDetails(transactions: [result.jwsRepresentation], products: products)
                }
            }
        }
    }

    public func syncAllTransactions() async {
        await processAllTransactions()
    }

    private nonisolated func processAllTransactions() async {
        var productIDs = Set<String>()
        var jwsTransactions = [String]()
        var verifiedTransactions = [Transaction]()

        for await result in Transaction.all {
            switch result {
            case .verified(let transaction):
                productIDs.insert(transaction.productID)
                jwsTransactions.append(result.jwsRepresentation)
                verifiedTransactions.append(transaction)
            case .unverified(let transaction, _):
                productIDs.insert(transaction.productID)
                jwsTransactions.append(result.jwsRepresentation)
            }
        }

        guard !productIDs.isEmpty else { return }

        let products = await fetchProducts(for: Array(productIDs))
        await sendDetails(transactions: jwsTransactions, products: products)

        for transaction in verifiedTransactions {
            await transaction.finish()
        }
    }

    private func postSDKInitialization(apiKey: String) async throws {
        var request = URLRequest(url: sdkInitializationUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            markSDKAsInitialized()
        }
    }

    private func getSystemInfo() -> [String: Any] {
        var systemInfo = [String: Any]()
        var deviceInfo = [String: Any]()
        let device = UIDevice.current
        deviceInfo["systemName"] = device.systemName
        deviceInfo["systemVersion"] = device.systemVersion
        deviceInfo["model"] = device.model
        deviceInfo["localizedModel"] = device.localizedModel
        deviceInfo["identifierForVendor"] = device.identifierForVendor?.uuidString
        deviceInfo["isPhysicalDevice"] = !isSimulator
        systemInfo["device_info"] = deviceInfo
        var windowInfo = [String: Any]()
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            let screen = windowScene.screen
            windowInfo["devicePixelRatio"] = screen.scale
            windowInfo["width"] = screen.bounds.width * screen.scale
            windowInfo["height"] = screen.bounds.height
        }
        systemInfo["window_info"] = windowInfo
        systemInfo["time_zone"] = TimeZone.current.identifier
        if #available(iOS 16, *) {
            systemInfo["language_code"] = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            systemInfo["language_code"] = Locale.current.languageCode ?? "en"
        }
        return systemInfo
    }

    private func postSystemInfo(data: [String: Any], apiKey: String) async -> GoMarketMeAffiliateMarketingData? {
        var requestData = data
        requestData["sdk_type"] = sdkType
        requestData["sdk_version"] = sdkVersion
        requestData["package_name"] = packageName

        do {
            let requestBody = try JSONSerialization.data(withJSONObject: requestData, options: [])
            var request = URLRequest(url: systemInfoUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.httpBody = requestBody

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP error: Status code \(httpResponse.statusCode)")
                } else {
                    print("Failed to send system info: Invalid HTTP response")
                }
                return nil
            }

            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], json.isEmpty {
                return nil
            }

            let decoder = JSONDecoder()

            do {
                let affiliateData = try decoder.decode(GoMarketMeAffiliateMarketingData.self, from: data)
                return affiliateData
            } catch {
                print("Error decoding response data: \(error.localizedDescription)")
                return nil
            }

        } catch {
            print("Error during system info posting: \(error.localizedDescription)")
            return nil
        }
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func isSDKInitialized() -> Bool {
        return UserDefaults.standard.bool(forKey: sdkInitializedKey)
    }

    private func markSDKAsInitialized() {
        UserDefaults.standard.set(true, forKey: sdkInitializedKey)
    }

    private func fetchProducts(for productIDs: [String]) async -> [Product] {
        do {
            return try await Product.products(for: productIDs)
        } catch {
            print("Failed to fetch products: \(error.localizedDescription)")
            return []
        }
    }

    private func sendDetails(transactions: [String], products: [Product]) async {

        func subscriptionUnitString(_ unit: Product.SubscriptionPeriod.Unit) -> String {
            switch unit {
            case .day: return "day"
            case .week: return "week"
            case .month: return "month"
            case .year: return "year"
            @unknown default: return "unknown"
            }
        }

        var requestData: [String: Any] = [
            "transactions": transactions,
        ]

        var productsArray: [[String: Any]] = []

        for product in products {
            let currencyCode = product.priceFormatStyle.currencyCode
            let localeId = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.currencyCode.rawValue: currencyCode])
            let currencySymbol = NSLocale(localeIdentifier: localeId).displayName(forKey: .currencySymbol, value: currencyCode) ?? currencyCode

            var productInfo: [String: Any] = [
                "packageName": packageName,
                "productID": product.id,
                "productTitle": product.displayName,
                "productDescription": product.description,
                "productPrice": product.displayPrice,
                "productRawPrice": product.price,
                "productCurrencyCode": currencyCode,
                "productCurrencySymbol": currencySymbol,
                "hashCode": String(product.hashValue)
            ]

            if let subInfo = product.subscription,
            let introOffer = subInfo.introductoryOffer {
                let introOfferDict: [String: Any] = [
                    "type": introOffer.type.rawValue,
                    "price": introOffer.price,
                    "localizedPrice": introOffer.price.formatted(),
                    "period": [
                        "unit": subscriptionUnitString(introOffer.period.unit),
                        "value": introOffer.period.value
                    ],
                    "paymentMode": introOffer.paymentMode.rawValue,
                    "periodCount": introOffer.periodCount,
                    "currencyCode": product.priceFormatStyle.currencyCode
                ]
                productInfo["introOffer"] = introOfferDict
            }

            productsArray.append(productInfo)
        }
        requestData["products"] = productsArray

        await self.sendEventToServer(eventType: "transactions", body: requestData)
    }

    private func sendEventToServer(eventType: String, body: [String: Any]) async {
        var request = URLRequest(url: eventUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(affiliateCampaignCode, forHTTPHeaderField: "x-affiliate-campaign-code")
        request.addValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(deviceId, forHTTPHeaderField: "x-device-id")
        request.addValue(eventType, forHTTPHeaderField: "x-event-type")
        request.addValue(packageName, forHTTPHeaderField: "x-package-name")
        request.addValue(sdkType, forHTTPHeaderField: "x-sdk-type")
        request.addValue(sdkVersion, forHTTPHeaderField: "x-sdk-version")
        request.addValue("app_store", forHTTPHeaderField: "x-source-name")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to send \(eventType): Network error: \(error.localizedDescription)")
        }
    }
}
