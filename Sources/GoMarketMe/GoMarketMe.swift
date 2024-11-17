import Foundation
import UIKit
import StoreKit

public class GoMarketMe: NSObject, ObservableObject, SKRequestDelegate {
    public static let shared = GoMarketMe()
    private var paymentQueueObserver: NSObjectProtocol?
    private let sdkInitializedKey = "GOMARKETME_SDK_INITIALIZED"
    private var affiliateCampaignCode: String?
    private var deviceId: String?
    private var apiKey: String = ""
    private let sdkInitializationUrl = URL(string: "https://api.gomarketme.net/v1/sdk-initialization")!
    private let systemInfoUrl = URL(string: "https://api.gomarketme.net/v1/mobile/system-info")!
    private let eventUrl = URL(string: "https://api.gomarketme.net/v1/event")!

    private var updateListenerTask: Task<Void, Error>? = nil
    private var currTransaction: Transaction? = nil
    
    private override init() {
        super.init()
    }
    
    public func initialize(apiKey: String) {
        self.apiKey = apiKey

        Task {
            await startListeningForUpdates()

            do {
                if !(await isSDKInitialized()) {
                    try await postSDKInitialization(apiKey: apiKey)
                }

                let systemInfo = await getSystemInfo()
                try await postSystemInfo(systemInfo: systemInfo, apiKey: apiKey)

                for await result in Transaction.all {
                    if affiliateCampaignCode != nil {
                        print("RE Processing pending transaction")
                        await processTransactionResult(result)
                    }
                }
                
            } catch {
                print("Error during SDK initialization: \(error.localizedDescription)")
            }
        }
    }

    public func startListeningForUpdates() async {
        updateListenerTask = Task {
            for await result in Transaction.currentEntitlements {
                if affiliateCampaignCode != nil {
                    await processTransactionResult(result)
                }
            }
        }
    }
    
    func fetchAndSendProduct(productId:String) async {
        do {
            let product = try await Product.products(for: [productId])
            if !product.isEmpty {
                sendProductDetails(product[0])
            }

        } catch {
            print("Failed to fetch products: \(error)")
        }
    }

    private func processTransactionResult(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            await fetchAndSendProduct(productId: transaction.productID)
            fetchPurchaseDetails(transaction: transaction)
        case .unverified(let transaction, _):
            await fetchAndSendProduct(productId: transaction.productID)
            fetchPurchaseDetails(transaction: transaction)
        }
    }
        
    deinit {
        updateListenerTask?.cancel()
    }

    private func postSDKInitialization(apiKey: String) async throws {
        var request = URLRequest(url: sdkInitializationUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            markSDKAsInitialized()
        } else {
            throw NSError(domain: "GoMarketMeSDK", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: "Failed to mark SDK as initialized."])
        }
    }

    private func getSystemInfo() async -> [String: Any] {
        var systemInfo = [String: Any]()
        var deviceInfo = [String: Any]()
        let device = await UIDevice.current
        deviceInfo["systemName"] = await device.systemName
        deviceInfo["systemVersion"] = await device.systemVersion
        deviceInfo["model"] = await device.model
        deviceInfo["localizedModel"] = await device.localizedModel
        deviceInfo["identifierForVendor"] = await device.identifierForVendor?.uuidString
        deviceInfo["isPhysicalDevice"] = !isSimulator
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

    private func postSystemInfo(systemInfo: [String: Any], apiKey: String) async throws {
        var request = URLRequest(url: systemInfoUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: systemInfo)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
               let jsonDict = jsonObject as? [String: Any] {
                affiliateCampaignCode = jsonDict["affiliate_campaign_code"] as? String
                deviceId = jsonDict["device_id"] as? String
                if deviceId != nil {
                    print(deviceId!)
                }
                print("SystemInfo sent successfully")
            } else {
                throw NSError(domain: "GoMarketMeSDK", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response JSON."])
            }
        } else {
            throw NSError(domain: "GoMarketMeSDK", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: "Failed to send SystemInfo."])
        }
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func isSDKInitialized() async -> Bool {
        return UserDefaults.standard.bool(forKey: sdkInitializedKey)
    }

    func markSDKAsInitialized() {
        UserDefaults.standard.set(true, forKey: sdkInitializedKey)
    }

    private func sendProductDetails(_ product: Product) {
        let productInfo = [
            "productID": product.id,
            "productTitle": product.displayName,
            "productDescription": product.description,
            "productPrice": product.displayPrice,
            "productRawPrice": product.price,
            "productCurrencyCode": product.priceFormatStyle.currencyCode,
            "productCurrencySymbol": product.priceFormatStyle.currencyCode,
            "hashCode": product.hashValue
        ] as [String: Any]
        
        self.sendEventToServer(eventType: "product", body: productInfo)
    }

    func refreshReceipt() {
        let request = SKReceiptRefreshRequest()
        request.delegate = self
        request.start()
    }
    
    // Called when the receipt refresh completes successfully
    public func requestDidFinish(_ request: SKRequest) {
        if let receiptURL = Bundle.main.appStoreReceiptURL,
            let receiptData = try? Data(contentsOf: receiptURL) {
            let base64EncodedReceipt = receiptData.base64EncodedString()
            sendPurchaseDetails(self.currTransaction!, receipt: base64EncodedReceipt)
        } else {
            print("Receipt is still missing.")
        }
    }
        
    // Called if the receipt refresh fails
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Failed to refresh receipt: \(error.localizedDescription)")
    }
    
    private func fetchPurchaseDetails(transaction: Transaction) {
        self.currTransaction = transaction
        refreshReceipt()
    }
    
    private func sendPurchaseDetails(_ transaction: Transaction, receipt: String) {
        let purchaseInfo: [String: Any] = [
                "productID": transaction.productID,
                "purchaseID": String(transaction.id),
                "transactionDate": transaction.purchaseDate.timeIntervalSince1970,
                "status": "",
                "verificationData": [
                    "localVerificationData": receipt,
                    "source": "app_store"
                ],
                "pendingCompletePurchase": "",
                "error": "",
                "hashCode": String(transaction.hashValue)
            ]
        self.sendEventToServer(eventType: "purchase", body: purchaseInfo)
    }

    private func sendEventToServer(eventType: String, body: [String: Any], completion: (() -> Void)? = nil) {
        var request = URLRequest(url: eventUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(deviceId ?? "", forHTTPHeaderField: "x-device-id")
        request.addValue(affiliateCampaignCode ?? "", forHTTPHeaderField: "x-affiliate-campaign-code")
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
