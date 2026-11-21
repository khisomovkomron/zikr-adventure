// AppCounterDisplay.swift
// Блок .counter: крупная цифра .num (clamp 54px / 17vw экрана / 72px) и подпись .cap.

import SwiftUI

struct AppCounterDisplay: View {
    let value: Int
    var caption: String
    /// ZKR-52: число, уже отформатированное в локали языка приложения (fmt() в вебе);
    /// nil — системная локаль, как раньше.
    var formattedValue: String? = nil

    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        let pointSize = Theme.Size.clampedCounter(width: Theme.Size.viewportWidth)
        let font = Theme.Font.scaledUIFont(.displayCounter, pointSize: pointSize, sizeCategory: sizeCategory, scales: false)
        VStack(spacing: Theme.Space.s1) {
            Text(formatted)
                .themeFont(.displayCounter, pointSize: pointSize, scales: false)
                .foregroundColor(Theme.Color.text)
                .monospacedDigit()
                .lineLimit(1)
                // ZKR-52: `.counter .num` line-height: 1 — строка высотой в размер шрифта, как в вебе.
                .padding(.vertical, -max(0, font.lineHeight - pointSize) / 2)

            Text(caption)
                .themeFont(.footnote)
                .themeLineHeight(.footnote, multiple: Theme.Font.bodyLineHeightMultiple)
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
        formattedValue ?? NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
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
