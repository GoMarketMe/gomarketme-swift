<div align="center">
    <img src="https://static.gomarketme.net/assets/gmm-icon.png" alt="GoMarketMe"/>
    <br>
    <h1>GoMarketMe Swift</h1>
    <p>Affiliate Marketing for iOS Applications.</p>
    <br>
    <br>
</div>


## Installation

### Swift Package Manager

- File > Swift Packages > Add Package Dependency
- Add `https://github.com/GoMarketMe/gomarketme-swift.git`
- Select "Exact Version" > "3.0.0"



Using an older version of Xcode? Do this instead:

- Navigate to the project navigator and select your project or the blue project icon.
- Package Dependencies > Add a New Package > +
- In the search bar that appears, enter `https://github.com/GoMarketMe/gomarketme-swift.git`
- Press "Add Package"

## Usage

### Import Library

```swift
import GoMarketMe
```

### Initialize Client

```swift
private let goMarketMe = GoMarketMe.shared

init() {
    goMarketMe.initialize(apiKey: "API_KEY") // Initialize with your API key
}
```

### Sync the Transactions (Recommended)

```swift
// Step 1: Retrieve the product
// Step 2: Attempt the purchase
// Step 3: Handle the purchase result
switch result { 
case .success(let verification):
    if case .verified(let transaction) = verification {
        await goMarketMe.syncAllTransactions() // <- add this line for faster processing
    }
}
```

Make sure to replace API_KEY with your actual GoMarketMe API key. You can find it on the onboarding page and under Profile > API Key.

Check out our <a href="https://github.com/GoMarketMe/gomarketme-swift-sample-app" target="_blank">sample app</a> for an example.