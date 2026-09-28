<div align="center">
  <img src="https://static.gomarketme.net/assets/gmm-icon.png" alt="GoMarketMe" />
  <br />
  <h1>GoMarketMe Affiliate Marketing SDK for Swift</h1>
  <p>Affiliate attribution, referral codes, and in-app purchase reporting for iOS apps.</p>
</div>

[![GitHub release][release_badge]][release_link]
[![License: MIT][license_badge]][license_link]

[GoMarketMe](https://gomarketme.co) is an affiliate marketing platform for mobile apps, with affiliate attribution, referral codes, and purchase reporting for iOS.

## Installation

### Swift Package Manager

- In Xcode, go to **File > Add Package Dependencies**.
- Enter `https://github.com/GoMarketMe/gomarketme-swift.git`.
- Select **Up to Next Major Version** with a minimum version of **6.0.1**.
- Click **Add Package**.

## Usage

GoMarketMe takes only a few lines to set up.

### Step 1: Initialize

Import `GoMarketMe` and initialize the SDK with your GoMarketMe API key:

```swift
import GoMarketMe

private let goMarketMe = GoMarketMe.shared

init() {
    goMarketMe.initialize(apiKey: "API_KEY")
}
```

Replace `API_KEY` with your actual GoMarketMe API key. You can find it during onboarding or in **Profile > [API Key](https://gomarketme.net/marketer/profile/#account-settings)**.

### Step 2: Sync Purchases (optional but recommended)

GoMarketMe automatically detects and reports purchases. We also recommend manually syncing after StoreKit, RevenueCat, Adapty, or another provider confirms a successful purchase. Call it before finishing the transaction if your purchase library controls that step:

```swift
await goMarketMe.syncAllTransactions()
```

### Step 3: Include iOS Consumable History (optional)

If your iOS app sells consumable in-app purchases, add this key to your app's `Info.plist`:

```xml
<key>SKIncludeConsumableInAppPurchaseHistory</key>
<true/>
```

That's it! GoMarketMe will automatically attribute and report affiliate sales in real time to your dashboard and your affiliates' dashboards.

## Optional features

### Step 4: Referral Codes

Referral codes work alongside affiliate links when a link isn't practical, such as in conversations, podcasts, videos, events, or print.

**GoMarketMe UI:** Add the remotely configured referral-code trigger to your SwiftUI view:

```swift
GoMarketMeReferralCodeTrigger()
```

Enable and customize its text, colors, typography, and layout in [GoMarketMe Referral Code settings](https://gomarketme.net/marketer/settings#referral-codes).

**Custom UI:** If your app provides its own code-entry interface, redeem the code after initialization:

```swift
let data = try await GoMarketMe.shared.redeemReferralCode("ASHLEY10")
```

Redemption throws `GoMarketMeReferralCodeError`. Use `code` for messages or UI behavior; the enum distinguishes invalid, expired, inactive, malformed-response, request, network, timeout, initialization, and unknown errors. `rawCode`, `statusCode`, and `isRetryable` are available for logging and retry decisions.

```swift
do {
    try await GoMarketMe.shared.redeemReferralCode(code)
} catch let error as GoMarketMeReferralCodeError where error.code == .invalidCode {
    showError("That referral code is not valid.")
}
```

**Placement:** Put the referral-code entry point on the first screen users see after installing the app, ideally during onboarding or immediately afterward.

Learn more about [Referral Codes](https://gomarketme.co/referral-codes/).

### Step 5: Programmatic Affiliate Marketing

Programmatic Affiliate Marketing lets your app personalize the user experience based on the affiliate and campaign that referred the user. For example, you can customize onboarding, paywalls, offers, or in-app content.

When attribution exists—after initialization detects an affiliate link or after a referral code is successfully redeemed, either programmatically or through GoMarketMe's UI—`GoMarketMe.shared.affiliateMarketingData` is populated.

If your app needs the attribution data immediately after initialization, await it first:

```swift
let data = await GoMarketMe.shared.initialize(apiKey: "API_KEY")
```

The returned data includes:

```jsonc
{
  "campaign": {
    "id": "campaign-id",
    "name": "Creator campaign",
    "status": "active",
    "type": "affiliate",
    "publicLinkUrl": null, // null unless this is a public campaign
    "metadata": {
      // Optional campaign-level properties configured in GoMarketMe
    }
  },
  "affiliate": {
    "id": "affiliate-id",
    "firstName": "Ashley",
    "lastName": "Creator",
    "countryCode": "US",
    "instagramAccount": "",
    "tiktokAccount": "",
    "xAccount": ""
  },
  "affiliateCampaign": {
    "metadata": {
      // Optional affiliate-level properties for this campaign configured in GoMarketMe
    }
  },
  "saleDistribution": {
    "platformPercentage": "10",
    "affiliatePercentage": "20"
  },
  "affiliateCampaignCode": "affiliate-campaign-code",
  "deviceId": "device-id",
  "offerCode": null, // null unless this is an offer-code campaign
  "referralCode": "ASHLEY10" // null unless attribution used a referral code
}
```

- `campaign.metadata` is configured under **Campaign detail > Advanced > Campaign-level metadata**.
- `affiliateCampaign.metadata` is configured under **Campaign detail > Affiliates > Invite or edit affiliate > Advanced > Affiliate-level metadata for this campaign**.

Every property shown above is present when attribution exists. Optional values are `nil` when they do not apply. The configurable metadata dictionaries are always present and are empty when no metadata is configured; GoMarketMe returns their free-form contents without interpreting them. If no attribution exists, `affiliateMarketingData` is `nil`.

Learn more about [Programmatic Affiliate Marketing](https://gomarketme.co/programmatic-affiliate-marketing/).

## Platform requirements

| Platform | Support | Notes |
|---|---:|---|
| iOS | ✅ | Requires iOS 15+ |
| Mac Catalyst | ✅ | For iOS apps that support Mac Catalyst |
| Apple Watch companion app | ✅ | Supported through the iOS app |
| Native macOS | Upon request | [Contact us](mailto:integrations@gomarketme.co) if your app requires native macOS support |
| Standalone watchOS | Upon request | [Contact us](mailto:integrations@gomarketme.co) if your app requires standalone watchOS support |
| tvOS | Upon request | [Contact us](mailto:integrations@gomarketme.co) if your app requires tvOS support |
| visionOS | Upon request | [Contact us](mailto:integrations@gomarketme.co) if your app requires visionOS support |

## IAP provider compatibility

| Provider | Support | Notes |
|---|---:|---|
| StoreKit | ✅ | Full support |
| RevenueCat | ✅ | Supports Apple IAPs |
| Adapty | ✅ | Supports Apple IAPs |

GoMarketMe works alongside StoreKit, RevenueCat, Adapty, and other IAP providers.

## Resources

- [GoMarketMe affiliate marketing platform](https://gomarketme.co)
- [GoMarketMe Swift package][release_link]
- [GoMarketMe Swift sample app](https://github.com/GoMarketMe/gomarketme-swift-sample-app)
- [Referral Codes](https://gomarketme.co/referral-codes/)
- [Programmatic Affiliate Marketing](https://gomarketme.co/programmatic-affiliate-marketing/)

## Support

For integration support, contact [integrations@gomarketme.co](mailto:integrations@gomarketme.co) or visit [https://gomarketme.co](https://gomarketme.co).

[release_badge]: https://img.shields.io/github/v/release/GoMarketMe/gomarketme-swift
[release_link]: https://github.com/GoMarketMe/gomarketme-swift
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
