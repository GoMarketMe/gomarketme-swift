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

public struct GoMarketMeVerifyReceiptData: Decodable {
    public let is_valid: Bool
    public let product_ids: [String]
}

public class GoMarketMe: NSObject, ObservableObject, SKRequestDelegate {

    public static let shared = GoMarketMe()
    private let sdkInitializedKey = "GOMARKETME_SDK_INITIALIZED"
    private let sdkType = "Swift"
    private let sdkVersion = "3.0.1"
    private var apiKey: String = ""
    private let sdkInitializationUrl = URL(string: "https://4v9008q1a5.execute-api.us-west-2.amazonaws.com/prod/v1/sdk-initialization")!
    private let systemInfoUrl = URL(string: "https://4v9008q1a5.execute-api.us-west-2.amazonaws.com/prod/v1/mobile/system-info")!
    private let verifyReceiptUrl = URL(string: "https://4v9008q1a5.execute-api.us-west-2.amazonaws.com/prod/v1/mobile/app-store-verify-receipt")!
    private let eventUrl = URL(string: "https://4v9008q1a5.execute-api.us-west-2.amazonaws.com/prod/v1/event")!
    private var _affiliateCampaignCode: String = ""
    private var _deviceId: String = ""
    private var _packageName = ""
    private var updatesTask: Task<Void, Never>?
    
    @Published public var affiliateMarketingData: GoMarketMeAffiliateMarketingData?

    private var backgroundTaskID: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid

    private override init() {
        super.init()
        listenForTransactions()
    }

    public func initialize(apiKey: String) {
        self.apiKey = apiKey

        Task {
            do {
                if !(await _isSDKInitialized()) {
                    try await _postSDKInitialization(apiKey: apiKey)
                }

                let systemInfo = await _getSystemInfo()
                _packageName = Bundle.main.bundleIdentifier ?? "Unknown"

                if let deviceInfo = systemInfo["device_info"] as? [String: Any],
                let identifierForVendor = deviceInfo["identifierForVendor"] as? String {
                    _deviceId = identifierForVendor
                }
                DispatchQueue.main.async {
                    Task {
                        do {
                            self.affiliateMarketingData = try await self._postSystemInfo(data: systemInfo, apiKey: apiKey) // Update on the main thread
                        } catch {
                            print("Failed to post system info: \(error)")
                            self.affiliateMarketingData = nil
                        }
                    }
                }

            } catch {
                print("Initialization failed with error: \(error)")
                affiliateMarketingData = nil
            }
        }
    }

    private func listenForTransactions() {
        updatesTask = Task.detached(priority: .background) {
            var refreshReceiptNeeded = false
            for await verificationResult in Transaction.all {
                refreshReceiptNeeded = true
                break
            }
            
            if refreshReceiptNeeded {
                await self.refreshReceipt()
            }
        }
    }

    public func syncAllTransactions() async {
        var refreshReceiptNeeded = false
        for await result in Transaction.all {
            refreshReceiptNeeded = true
            break
        }

        if refreshReceiptNeeded {
            await self.refreshReceipt()
        }
    }

    private func _postSDKInitialization(apiKey: String) async throws {
        var request = URLRequest(url: sdkInitializationUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            _markSDKAsInitialized()
        }
    }

    private func _getSystemInfo() async -> [String: Any] {
        var systemInfo = [String: Any]()
        var deviceInfo = [String: Any]()
        let device = await UIDevice.current
        deviceInfo["systemName"] = await device.systemName
        deviceInfo["systemVersion"] = await device.systemVersion
        deviceInfo["model"] = await device.model
        deviceInfo["localizedModel"] = await device.localizedModel
        deviceInfo["identifierForVendor"] = await device.identifierForVendor?.uuidString
        deviceInfo["isPhysicalDevice"] = !_isSimulator
        systemInfo["device_info"] = deviceInfo
        var windowInfo = [String: Any]()
        let screen = await UIScreen.main
        windowInfo["devicePixelRatio"] = await screen.scale
        windowInfo["width"] = await screen.bounds.width * screen.scale
        windowInfo["height"] = await screen.bounds.height
        systemInfo["window_info"] = windowInfo
        systemInfo["time_zone"] = TimeZone.current.identifier
        systemInfo["language_code"] = Locale.current.languageCode ?? "en"
        return systemInfo
    }

    private func _postSystemInfo(data: [String: Any], apiKey: String) async -> GoMarketMeAffiliateMarketingData? {
        var requestData = data
        requestData["sdk_type"] = sdkType
        requestData["sdk_version"] = sdkVersion
        requestData["package_name"] = _packageName
        
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

    private func _postVerifyReceipt(encodedReceipt: String) async -> GoMarketMeVerifyReceiptData? {
        
        let requestData: [String: Any] = [
            "package_name": _packageName,
            "encoded_receipt": encodedReceipt
        ]
        
        do {
            let requestBody = try JSONSerialization.data(withJSONObject: requestData, options: [])
            var request = URLRequest(url: verifyReceiptUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue(_deviceId, forHTTPHeaderField: "x-device-id")
            request.setValue(sdkType, forHTTPHeaderField: "x-sdk-type")
            request.setValue(sdkVersion, forHTTPHeaderField: "x-sdk-version")
            request.httpBody = requestBody
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP error: Status code \(httpResponse.statusCode)")
                } else {
                    print("Failed to send receipt for verification: Invalid HTTP response")
                }
                return nil
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], json.isEmpty {
                return nil
            }

            let decoder = JSONDecoder()
            
            do {
                let affiliateData = try decoder.decode(GoMarketMeVerifyReceiptData.self, from: data)
                return affiliateData
            } catch {
                print("Error decoding response data: \(error.localizedDescription)")
                return nil
            }
            
        } catch {
            print("Error during receipt validation posting: \(error.localizedDescription)")
            return nil
        }
    }

    private var _isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func _isSDKInitialized() async -> Bool {
        return UserDefaults.standard.bool(forKey: sdkInitializedKey)
    }

    private func _markSDKAsInitialized() {
        UserDefaults.standard.set(true, forKey: sdkInitializedKey)
    }

    private func endBackgroundTask() {
        let taskID = backgroundTaskID
        backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        if taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }

    private func refreshReceipt() async {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "SKReceiptRefreshRequest") {
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = .invalid
        }

        let request = SKReceiptRefreshRequest()
        request.delegate = self
        request.start()
    }

    public func requestDidFinish(_ request: SKRequest) {
        Task {
            defer {

                request.cancel() // important
                self.endBackgroundTask()
            }

            guard
                let receiptURL = Bundle.main.appStoreReceiptURL,
                let receiptData = try? Data(contentsOf: receiptURL)
            else {
                return
            }

            let encodedReceipt = receiptData.base64EncodedString()

            guard let verificationResult = await self._postVerifyReceipt(encodedReceipt: encodedReceipt),
                verificationResult.is_valid else {
                return
            }

            var productIDs = Set(verificationResult.product_ids)

            for await verificationResult in Transaction.all {
                switch verificationResult {
                case .verified(let transaction):
                    productIDs.insert(transaction.productID)
                case .unverified(let transaction, _):
                    productIDs.insert(transaction.productID)
                }
            }

            fetchProducts(for: Array(productIDs)) { products in
                self._sendDetails(encodedReceipt, products: products)
                // endBackgroundTask is already handled by `defer`
            }
        }
    }

    public func request(_ request: SKRequest, didFailWithError error: Error) {
        print("SKReceiptRefreshRequest failed with error: \(error)")

        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    private func fetchProducts(for productIDs: [String], completion: @escaping ([Product]) -> Void) {
        Task {
            do {
                let products = try await Product.products(for: productIDs)
                DispatchQueue.main.async {
                    completion(products)
                }
            } catch {
                print("Failed to fetch products: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    private func _sendDetails(_ encodedReceipt: String, products: [Product]) {

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
            "encodedReceipt": encodedReceipt,
        ]

        var productsArray: [[String: Any]] = []

        for product in products {
            var productInfo: [String: Any] = [
                "packageName": _packageName,
                "productID": product.id,
                "productTitle": product.displayName,
                "productDescription": product.description,
                "productPrice": product.displayPrice,
                "productRawPrice": product.price,
                "productCurrencyCode": product.priceFormatStyle.currencyCode ?? "",
                "productCurrencySymbol": product.priceFormatStyle.currencyCode ?? "",
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
                    "currencyCode": product.priceFormatStyle.currencyCode ?? ""
                ]
                productInfo["introOffer"] = introOfferDict
            }

            productsArray.append(productInfo)
        }
        requestData["products"] = productsArray

        self._sendEventToServer(eventType: "encoded-receipt", body: requestData)
    }

    private func _sendEventToServer(eventType: String, body: [String: Any], completion: (() -> Void)? = nil) {
        var request = URLRequest(url: eventUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(_affiliateCampaignCode, forHTTPHeaderField: "x-affiliate-campaign-code")
        request.addValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(_deviceId, forHTTPHeaderField: "x-device-id")
        request.addValue(eventType, forHTTPHeaderField: "x-event-type")
        request.addValue(_packageName, forHTTPHeaderField: "x-package-name")
        request.addValue(sdkType, forHTTPHeaderField: "x-sdk-type")
        request.addValue(sdkVersion, forHTTPHeaderField: "x-sdk-version")
        request.addValue("app_store", forHTTPHeaderField: "x-source-name")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to send \(eventType): Network error: \(error.localizedDescription)")
                return
            }
            let response = response as? HTTPURLResponse
            completion?()
        }
        task.resume()
    }
}