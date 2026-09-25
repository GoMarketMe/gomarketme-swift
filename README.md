<div align="center">
    <img src="https://static.gomarketme.net/assets/gmm-icon.png" alt="GoMarketMe"/>
    <br>
    <h1>GoMarketMe Swift SDK</h1>
    <p>Affiliate marketing for iOS applications.</p>
</div>

## Installation

### Swift Package Manager

- In Xcode, go to **File > Add Package Dependencies**
- Enter `https://github.com/GoMarketMe/gomarketme-swift.git`
- Select **Up to Next Major Version**, min: **6.0.0**
- Click **Add Package**

## Usage

GoMarketMe takes only a few lines to set up.

### Step 1: Initialize

Import the `GoMarketMe` package and initialize the SDK with your API key.

```swift
import GoMarketMe

private let goMarketMe = GoMarketMe.shared

init() {
    goMarketMe.initialize(apiKey: "API_KEY")
}
```

Replace `API_KEY` with your actual GoMarketMe API key. You can find it during onboarding or in **Profile > [API Key](https://gomarketme.net/marketer/profile/#account-settings)**.

### Step 2: Sync Purchases (recommended)

GoMarketMe automatically detects and reports purchases. For additional reliability, we also recommend manually syncing after StoreKit, RevenueCat, Adapty, or another provider confirms a successful purchase:

```swift
await goMarketMe.syncAllTransactions()
```

Call it before finishing the transaction when your purchase library controls that step.

### Step 3: Only for iOS consumables

If your iOS app sells consumable in-app purchases, add this key to your app's `Info.plist`:

```xml
<key>SKIncludeConsumableInAppPurchaseHistory</key>
<true/>
```

That's it. GoMarketMe will automatically attribute and report affiliate sales in real time to your dashboard and your affiliates' dashboards.

## Optional

### Step 4: Referral Codes

Referral codes work alongside affiliate links when a link isn't practical, such as in conversations, podcasts, videos, events, or print.

Enable Referral Codes in one line:

```swift
GoMarketMeReferralCodeTrigger()
```

**Placement:** Put this referral UI on the first screen users see after installing the app, ideally during onboarding or immediately afterward.

Customize its text, colors, typography, and layout directly in [https://gomarketme.net/marketer/settings#referral-codes](https://gomarketme.net/marketer/settings#referral-codes).

Learn more about [Referral Codes](https://gomarketme.co/referral-codes/).

### Step 5: Programmatic Affiliate Marketing

Programmatic Affiliate Marketing lets your app personalize the user experience based on the affiliate and campaign that referred the user. For example, you can customize onboarding, paywalls, offers, or in-app content.

Use the affiliate data returned during initialization:

```swift
Task {
    if let data = await GoMarketMe.shared.initialize(apiKey: "API_KEY") {
        print("Affiliate ID:", data.affiliate.id)
        print("Affiliate %:", data.saleDistribution.affiliatePercentage)
        print("Campaign ID:", data.campaign.id)
    }
}
```

Learn more about [Programmatic Affiliate Marketing](https://gomarketme.co/programmatic-affiliate-marketing/).

## Platform Support

| Platform | Support | Notes |
|---|---:|---|
| iOS | ✅ | Requires iOS 15+ |
| Mac Catalyst | ✅ | For iOS apps that support Mac Catalyst |
| Apple Watch companion app | ✅ | Supported through the iOS app |
| Native macOS | Upon request | [Contact us](mailto:integrations@gomarketme.co) if your app requires native macOS support |
| Standalone watchOS | Upon request | [Contact us](mailto:integrations@gomarketme.co) if your app requires standalone watchOS support |
| tvOS | Upon request | [Contact us](mailto:integrations@gomarketme.co) if your app requires tvOS support |
| visionOS | Upon request | [Contact us](mailto:integrations@gomarketme.co) if your app requires visionOS support |

## IAP Provider Compatibility

| Provider | Support | Notes |
|---|---:|---|
| StoreKit | ✅ | Full support |
| RevenueCat | ✅ | Supports Apple IAPs |
| Adapty | ✅ | Supports Apple IAPs |

GoMarketMe works alongside StoreKit, RevenueCat, Adapty, and other IAP providers.

## Support

Check out our sample iOS app at [https://github.com/GoMarketMe/gomarketme-swift-sample-app](https://github.com/GoMarketMe/gomarketme-swift-sample-app).

For integration support, contact [integrations@gomarketme.co](mailto:integrations@gomarketme.co) or visit [https://gomarketme.co](https://gomarketme.co).
