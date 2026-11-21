// AppFootnote.swift
// Подпись .foot: 14 pt, --text2.

import SwiftUI

struct AppFootnote: View {
    let text: String

    var body: some View {
        Text(text)
            .themeFont(.footnote)
            .foregroundColor(Theme.Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Space.s1)
            .padding(.top, Theme.Space.s2)
            .accessibilityLabel(text)
    }
}

struct AppFootnote_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "AppFootnote") {
            AppFootnote(text: "Цель необязательна. Пропустить день — нормально, ничего не теряется.")
                .padding(Theme.Space.s4)
                .background(Theme.Color.bg)
        }
    }
}
