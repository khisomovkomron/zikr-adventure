// AppCounterDisplay.swift
// Блок .counter: крупная цифра .num (clamp 54px / 17vw экрана / 72px) и подпись .cap.

import SwiftUI

struct AppCounterDisplay: View {
    let value: Int
    var caption: String

    var body: some View {
        VStack(spacing: Theme.Space.s1) {
            Text(formatted)
                .themeFont(
                    .displayCounter,
                    pointSize: Theme.Size.clampedCounter(width: Theme.Size.viewportWidth),
                    scales: false
                )
                .foregroundColor(Theme.Color.text)
                .monospacedDigit()
                .lineLimit(1)

            Text(caption)
                .themeFont(.footnote)
                .foregroundColor(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(caption)
        .accessibilityValue(formatted)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var formatted: String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }
}

struct AppCounterDisplay_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "AppCounterDisplay") {
            AppCounterDisplay(value: 12840, caption: "всего повторений")
                .padding(Theme.Space.s4)
                .background(Theme.Color.bg)
        }
    }
}
