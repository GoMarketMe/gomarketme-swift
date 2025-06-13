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

public class GoMarketMe: NSObject, ObservableObject, SKRequestDelegate {
    public static let shared = GoMarketMe()
    private let sdkInitializedKey = "GOMARKETME_SDK_INITIALIZED"
    private let sdkType = "Swift"
    private let sdkVersion = "2.2.1"
    private var apiKey: String = ""
    private let sdkInitializationUrl = URL(string: "https://4v9008q1a5.execute-api.us-west-2.amazonaws.com/prod/v1/sdk-initialization")!
    private let systemInfoUrl = URL(string: "https://4v9008q1a5.execute-api.us-west-2.amazonaws.com/prod/v1/mobile/system-info")!
    private let eventUrl = URL(string: "https://4v9008q1a5.execute-api.us-west-2.amazonaws.com/prod/v1/event")!
    private var _affiliateCampaignCode: String = ""
    private var _deviceId: String = ""
    private var _packageName = ""
    
    @Published public var affiliateMarketingData: GoMarketMeAffiliateMarketingData?

    private var backgroundTaskID: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    private var currTransaction: Transaction? = nil
    
    private override init() {
        super.init()
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

                // Dispatch async task to main queue
                DispatchQueue.main.async {
                    Task {
                        do {
                            self.affiliateMarketingData = try await self._postSystemInfo(data: systemInfo, apiKey: apiKey) // Update on the main thread
                        } catch {
                            print("Failed to post system info: \(error)")
                            self.affiliateMarketingData = nil // Handle any errors during system info posting
                        }
                    }
                }

                await syncAllTransactions()

                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(appWillEnterForeground),
                    name: UIApplication.willEnterForegroundNotification,
                    object: nil
                )
            } catch {
                print("Initialization failed with error: \(error)")
                affiliateMarketingData = nil // Make sure to reset on failure
            }
        }
    }


    @objc private func appWillEnterForeground() {
        Task {
            await syncAllTransactions()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func processTransactionResult(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            await syncTransaction(transaction: transaction)
        case .unverified(let transaction, _):
            await syncTransaction(transaction: transaction)
        }
    }

    public func syncAllTransactions() async {
            for await result in Transaction.all {
                await processTransactionResult(result)
            }
    }

    public func syncTransaction(transaction: Transaction) async {
            _fetchPurchaseDetails(transaction: transaction)
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
                print("System Info sent successfully")
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
        if backgroundTaskID != UIBackgroundTaskIdentifier.invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        }
    }

    private func refreshReceipt() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "SKReceiptRefreshRequest") {
            self.endBackgroundTask()
        }

        let request = SKReceiptRefreshRequest()
        request.delegate = self
        request.start()
    }

    public func requestDidFinish(_ request: SKRequest) {
        guard
            let receiptURL = Bundle.main.appStoreReceiptURL,
            let receiptData = try? Data(contentsOf: receiptURL),
            let currTransaction = self.currTransaction
        else {
            self.endBackgroundTask()
            return
        }

        let base64EncodedReceipt = receiptData.base64EncodedString()
        
        fetchProducts(for: [currTransaction.productID]) { products in
            self._sendConsolidatedPurchaseDetails(currTransaction, receipt: base64EncodedReceipt, products: products)
        }

        self.endBackgroundTask()
    }
    
    private func _fetchPurchaseDetails(transaction: Transaction) {
        self.currTransaction = transaction
        refreshReceipt()
    }
    
    private func fetchProducts(for productIDs: [String], completion: @escaping ([Product]) -> Void) {
        Task {
            do {
                let products = try await Product.products(for: productIDs)
                completion(products)
            } catch {
                print("Failed to fetch products: \(error.localizedDescription)")
                completion([])
            }
        }
    }

    private func _sendConsolidatedPurchaseDetails(_ transaction: Transaction, receipt: String, products: [Product]) {

        func subscriptionUnitString(_ unit: Product.SubscriptionPeriod.Unit) -> String {
            switch unit {
            case .day: return "day"
            case .week: return "week"
            case .month: return "month"
            case .year: return "year"
            @unknown default: return "unknown"
            }
        }

        var purchaseInfo: [String: Any] = [
            "packageName": _packageName,
            "productID": transaction.productID,
            "purchaseID": String(transaction.id),
            "transactionDate": transaction.purchaseDate.timeIntervalSince1970,
            "status": "",
            "verificationData": [
                "localVerificationData": receipt,
                "serverVerificationData": receipt,
                "source": "app_store"
            ],
            "pendingCompletePurchase": "",
            "error": "",
            "hashCode": String(transaction.hashValue)
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

        purchaseInfo["products"] = productsArray

        self._sendEventToServer(eventType: "purchase", body: purchaseInfo)
    }

    private func _sendEventToServer(eventType: String, body: [String: Any], completion: (() -> Void)? = nil) {
        var request = URLRequest(url: eventUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(_deviceId, forHTTPHeaderField: "x-device-id")
        request.addValue(_affiliateCampaignCode, forHTTPHeaderField: "x-affiliate-campaign-code")
        request.addValue(eventType, forHTTPHeaderField: "x-event-type")
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
