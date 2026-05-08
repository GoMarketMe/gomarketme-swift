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
- Select **Up to Next Major Version**, min: **5.0.2**
- Click **Add Package**

## Usage

⚙️ Basic Integration

To initialize GoMarketMe, import the `GoMarketMe` package and initialize the SDK with your API key:

```swift
import GoMarketMe

private let goMarketMe = GoMarketMe.shared

init() {
    goMarketMe.initialize(apiKey: "API_KEY") // Initialize with your API key
}
```

No further steps needed. The SDK automatically attributes and reports your affiliate sales in real time.

> `syncAllTransactions()` is no longer needed in version `5.0.0`. It remains available as a deprecated no-op so existing apps can upgrade without immediately removing old calls.

⚙️ OR - Advanced Integration ([Programmatic Affiliate Marketing](https://gomarketme.co/programmatic-affiliate-marketing/))

Use this approach for more advanced scenarios, such as:

- Affiliate-aware paywalls: Offer exclusive pricing or promotions to users acquired through affiliate campaigns.
- Personalized onboarding: For example, a social or fitness app can automatically make new users follow the influencer who referred them, strengthening engagement and maximizing the affiliate's impact.

```swift
import GoMarketMe

private let goMarketMe = GoMarketMe.shared

init() {
    let sdk = GoMarketMe.shared

    Task {
        let data = await sdk.initialize(apiKey: "API_KEY") // Initialize with your API key

        if let data {
            // maps to GoMarketMe > Affiliates > Export > id column
            print("Affiliate ID:", data.affiliate.id)
            
            // maps to GoMarketMe > Campaigns > [Name] > Affiliate's Revenue Split (%)
            print("Affiliate %:", data.saleDistribution.affiliatePercentage) 

            // maps to GoMarketMe > Campaigns > [Name] > id in the URL
            print("Campaign ID:", data.campaign.id)

            // Use this data to customize onboarding, paywalls, promotions, or in-app experiences.
        }
    }
}
```

Make sure to replace `API_KEY` with your actual GoMarketMe API key. You can find it on the product onboarding page and under **Profile > API Key**.

## Support

Check out our sample iOS app at [https://github.com/GoMarketMe/gomarketme-swift-sample-app](https://github.com/GoMarketMe/gomarketme-swift-sample-app).

If you run into any issues, please reach out to us at [integrations@gomarketme.co](mailto:integrations@gomarketme.co) or visit [https://gomarketme.co](https://gomarketme.co).
