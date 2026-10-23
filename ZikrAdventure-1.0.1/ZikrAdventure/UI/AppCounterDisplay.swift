// AppCounterDisplay.swift
// Блок .counter: крупная цифра .num (clamp 54px / 17vw / 72px) и подпись .cap.

import SwiftUI

struct AppCounterDisplay: View {
    let value: Int
    var caption: String
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: Theme.Space.s1) {
            Text(formatted)
                .themeFont(
                    .displayCounter,
                    pointSize: Theme.Size.clampedCounter(width: availableWidth),
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
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: CounterWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(CounterWidthKey.self) { availableWidth = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(caption)
        .accessibilityValue(formatted)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var formatted: String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }
}

private struct CounterWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
