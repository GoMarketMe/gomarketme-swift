import Foundation
import UIKit
import StoreKit

public class GoMarketMe: NSObject, SKPaymentTransactionObserver {
    public static let shared = GoMarketMe()
    private let sdkInitializedKey = "GOMARKETME_SDK_INITIALIZED"
    private var affiliateCampaignCode: String = ""
    private var deviceId: String = ""
    private var apiKey: String = ""
    private let sdkInitializationUrl = URL(string: "https://api.gomarketme.net/v1/sdk-initialization")!
    private let systemInfoUrl = URL(string: "https://api.gomarketme.net/v1/mobile/system-info")!
    private let eventUrl = URL(string: "https://api.gomarketme.net/v1/event")!

    private override init() {
        super.init()
        // Additional initialization if necessary
    }

    public func initialize(apiKey: String) {
        self.apiKey = apiKey
        if !isSDKInitialized() {
            postSDKInitialization(apiKey: apiKey)
        }
        self.getSystemInfo { systemInfo in
            self.postSystemInfo(systemInfo: systemInfo, apiKey: apiKey) {
                self.addListener(apiKey: apiKey)
            }
        }
    }

    private func addListener(apiKey: String) {
        SKPaymentQueue.default().add(self)
    }

    private func postSDKInitialization(apiKey: String) {
        var request = URLRequest(url: sdkInitializationUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                self.markSDKAsInitialized()
            } else {
                print("Error marking the SDK as initialized")
            }
        }
        task.resume()
    }

    private func getSystemInfo(completion: @escaping ([String: Any]) -> Void) {
        var systemInfo = [String: Any]()
        let device = UIDevice.current
        systemInfo["systemName"] = device.systemName
        systemInfo["systemVersion"] = device.systemVersion
        systemInfo["model"] = device.model
        systemInfo["localizedModel"] = device.localizedModel
        systemInfo["identifierForVendor"] = device.identifierForVendor?.uuidString
        systemInfo["isPhysicalDevice"] = !isSimulator

        let screen = UIScreen.main
        systemInfo["devicePixelRatio"] = screen.scale
        systemInfo["width"] = screen.bounds.width
        systemInfo["height"] = screen.bounds.height

        systemInfo["time_zone_code"] = TimeZone.current.identifier
        systemInfo["language_code"] = Locale.current.languageCode

        completion(systemInfo)
    }

    private func postSystemInfo(systemInfo: [String: Any], apiKey: String, completion: @escaping () -> Void) {
        var request = URLRequest(url: systemInfoUrl)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["device_info": systemInfo])
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if let data = data, let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.handlePostSystemInfoResponse(jsonResponse)
                    print("SystemInfo sent successfully")
                    completion()
                }
            } else {
                print("Failed to send SystemInfo. Status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
        }
        task.resume()
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    func markSDKAsInitialized() {
        UserDefaults.standard.set(true, forKey: sdkInitializedKey)
    }

    func isSDKInitialized() -> Bool {
        return UserDefaults.standard.bool(forKey: sdkInitializedKey)
    }

    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased, .restored:
                if !affiliateCampaignCode.isEmpty {
                    completeTransaction(transaction)
                }
            case .failed:
                failedTransaction(transaction)
            case .deferred, .purchasing:
                break
            @unknown default:
                break
            }
        }
    }

    private func handlePostSystemInfoResponse(_ response: [String: Any]) {
        if let affiliateCode = response["affiliate_campaign_code"] as? String {
            self.affiliateCampaignCode = affiliateCode
        }
        if let deviceID = response["device_id"] as? String {
            self.deviceId = deviceID
        }
    }

    private func completeTransaction(_ transaction: SKPaymentTransaction) {
        let purchaseDetails = serializePurchaseDetails(transaction)
        sendEventToServer(eventType: "purchase", body: purchaseDetails) {
            SKPaymentQueue.default().finishTransaction(transaction)
        }
    }

    private func failedTransaction(_ transaction: SKPaymentTransaction) {
        if let error = transaction.error as NSError? {
            print("Transaction Error: \(error.localizedDescription)")
        }
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func sendEventToServer(eventType: String, body: [String: Any], completion: @escaping () -> Void) {
        let url = URL(string: eventUrl.absoluteString + "?eventType=\(eventType)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(deviceId, forHTTPHeaderField: "x-device-id")
        request.addValue(affiliateCampaignCode, forHTTPHeaderField: "x-affiliate-campaign-code")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                print("\(eventType) sent successfully")
                completion()
            } else {
                print("Failed to send \(eventType). Status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
        }
        task.resume()
    }

    private func serializePurchaseDetails(_ transaction: SKPaymentTransaction) -> [String: Any] {
        var details = [String: Any]()
        details["productID"] = transaction.payment.productIdentifier
        details["transactionDate"] = transaction.transactionDate?.timeIntervalSince1970 ?? 0
        details["status"] = transaction.transactionState.rawValue  // Enum to raw value
        details["transactionID"] = transaction.transactionIdentifier ?? ""
        
        // Include additional fields as necessary
        if transaction.transactionState == .restored {
            details["originalTransactionID"] = transaction.original?.transactionIdentifier ?? ""
        }

        // Include error details if transaction failed
        if let error = transaction.error as NSError? {
            details["error"] = [
                "code": error.code,
                "domain": error.domain,
                "userInfo": error.userInfo
            ]
        }

        return details
    }
}
