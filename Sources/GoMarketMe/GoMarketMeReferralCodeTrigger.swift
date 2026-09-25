import SwiftUI

@available(iOS 15.0, *)
public struct GoMarketMeReferralCodeTrigger: View {
    @ObservedObject private var sdk: GoMarketMe
    @State private var settings: TriggerSettings?
    @State private var isOpening = false

    private let onResult: ((GoMarketMeAffiliateMarketingData?) -> Void)?
    private let onError: ((Error) -> Void)?

    public init(
        sdk: GoMarketMe = .shared,
        onResult: ((GoMarketMeAffiliateMarketingData?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.sdk = sdk
        self.onResult = onResult
        self.onError = onError
    }

    public var body: some View {
        Group {
            if let settings {
                HStack(spacing: 0) {
                    if settings.alignment != .leading { Spacer(minLength: 0) }
                    Button(action: openSheet) {
                        Text(settings.text)
                            .font(settings.font)
                            .fontWeight(settings.fontWeight)
                            .underline(settings.isLink && settings.linkUnderline)
                            .foregroundStyle(settings.foregroundColor)
                            .padding(.horizontal, settings.isLink ? 0 : settings.horizontalPadding)
                            .padding(.vertical, settings.isLink ? 0 : settings.verticalPadding)
                            .frame(minHeight: 44)
                            .background(settings.isLink ? Color.clear : settings.buttonBackground)
                            .overlay {
                                if !settings.isLink && settings.borderWidth > 0 {
                                    RoundedRectangle(cornerRadius: settings.borderRadius)
                                        .stroke(settings.buttonBorder, lineWidth: settings.borderWidth)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: settings.borderRadius))
                            .opacity(isOpening ? 0.6 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isOpening)
                    .accessibilityLabel(settings.text)
                    if settings.alignment != .trailing { Spacer(minLength: 0) }
                }
            } else {
                // Keep a mounted view while configuration is loading so SwiftUI
                // reliably starts and observes the task below.
                Color.clear
                    .frame(height: 0)
                    .accessibilityHidden(true)
            }
        }
        .task(id: sdk.isInitialized) {
            guard sdk.isInitialized, settings == nil else { return }
            do {
                settings = TriggerSettings(raw: try await sdk.referralCodeSettings())
            } catch {
                settings = .defaults
                onError?(error)
            }
        }
    }

    private func openSheet() {
        guard !isOpening else { return }
        isOpening = true
        Task { @MainActor in
            defer { isOpening = false }
            do {
                let result = try await sdk.showReferralCodeSheet()
                onResult?(result)
            } catch {
                onError?(error)
            }
        }
    }
}

@available(iOS 15.0, *)
private struct TriggerSettings {
    enum Alignment {
        case leading
        case center
        case trailing
    }

    static let defaults = TriggerSettings(raw: [:])

    let isLink: Bool
    let text: String
    let alignment: Alignment
    let font: Font
    let fontWeight: Font.Weight
    let linkUnderline: Bool
    let foregroundColor: Color
    let buttonBackground: Color
    let buttonBorder: Color
    let borderWidth: CGFloat
    let borderRadius: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    init(raw response: [String: Any]) {
        let defaults: [String: Any] = [
            "triggerType": "link",
            "triggerText": "Have a referral code?",
            "triggerAlignment": "center",
            "triggerFontSize": 15.0,
            "triggerFontWeight": "500",
            "triggerLinkColor": "#1F2937",
            "triggerLinkUnderline": false,
            "triggerButtonBackground": "#3B82F6",
            "triggerButtonTextColor": "#FFFFFF",
            "triggerButtonBorder": "#3B82F6",
            "triggerButtonBorderWidth": 1.0,
            "triggerButtonBorderRadius": 10.0,
            "triggerButtonPaddingHorizontal": 16.0,
            "triggerButtonPaddingVertical": 10.0
        ]
        let supplied = (response["marketer_settings"] as? [String: Any])
            ?? (response["default_settings"] as? [String: Any])
            ?? response
        let value: (String) -> Any? = { supplied[$0] ?? defaults[$0] }

        isLink = (value("triggerType") as? String) != "button"
        text = (value("triggerText") as? String) ?? "Have a referral code?"
        alignment = switch value("triggerAlignment") as? String {
        case "left": .leading
        case "right": .trailing
        default: .center
        }
        let fontSize = Self.number(value("triggerFontSize"), fallback: 15, minimum: 10)
        if let family = value("family") as? String, !family.isEmpty {
            font = .custom(family, size: fontSize)
        } else {
            font = .system(size: fontSize)
        }
        fontWeight = Self.weight(value("triggerFontWeight") as? String)
        linkUnderline = (value("triggerLinkUnderline") as? Bool) ?? false
        foregroundColor = Self.color(
            value(isLink ? "triggerLinkColor" : "triggerButtonTextColor"),
            fallback: isLink ? "#1F2937" : "#FFFFFF"
        )
        buttonBackground = Self.color(value("triggerButtonBackground"), fallback: "#3B82F6")
        buttonBorder = Self.color(value("triggerButtonBorder"), fallback: "#3B82F6")
        borderWidth = Self.number(value("triggerButtonBorderWidth"), fallback: 1)
        borderRadius = Self.number(value("triggerButtonBorderRadius"), fallback: 10)
        horizontalPadding = Self.number(value("triggerButtonPaddingHorizontal"), fallback: 16)
        verticalPadding = Self.number(value("triggerButtonPaddingVertical"), fallback: 10)
    }

    private static func number(
        _ value: Any?,
        fallback: CGFloat,
        minimum: CGFloat = 0,
        maximum: CGFloat = 200
    ) -> CGFloat {
        let parsed = (value as? NSNumber).map { CGFloat(truncating: $0) }
            ?? (value as? String).flatMap(Double.init).map { CGFloat($0) }
            ?? fallback
        return min(max(parsed, minimum), maximum)
    }

    private static func weight(_ value: String?) -> Font.Weight {
        switch value {
        case "100": .ultraLight
        case "200": .thin
        case "300": .light
        case "400", "normal": .regular
        case "600": .semibold
        case "700", "bold": .bold
        case "800": .heavy
        case "900": .black
        default: .medium
        }
    }

    private static func color(_ value: Any?, fallback: String) -> Color {
        let raw = ((value as? String) ?? fallback).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard (raw.count == 6 || raw.count == 8), let number = UInt64(raw, radix: 16) else {
            return color(fallback, fallback: "#000000")
        }
        let red = Double((number >> (raw.count == 8 ? 24 : 16)) & 0xff) / 255
        let green = Double((number >> (raw.count == 8 ? 16 : 8)) & 0xff) / 255
        let blue = Double((number >> (raw.count == 8 ? 8 : 0)) & 0xff) / 255
        let alpha = raw.count == 8 ? Double(number & 0xff) / 255 : 1
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
