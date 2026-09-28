## 6.0.1

- Expose free-form campaign, affiliate, and affiliate-campaign metadata in attribution results.
- Add `redeemReferralCode(_:)` for apps that provide their own code-entry UI.
- Expose structured referral-code errors with semantic code, HTTP status, and retryability.

## 6.0.0

- Add a shared, remotely configurable referral-code sheet and optional trigger.
- Redeem codes in the native core and update affiliate/purchase attribution.
- Include v6 native binaries; retain the existing purchase event schema.
- Expose optional `referralCode` attribution data and prevent referral codes from overriding existing attribution.
- Add `GoMarketMeReferralCodeTrigger`, a SwiftUI trigger driven by the remotely configured settings.
