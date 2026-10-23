// AppLink.swift
// Inline-ссылка: color.accent, без подчёркивания и системного синего.

import SwiftUI

struct AppLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .themeFont(.body)
                .foregroundColor(Theme.Color.accent)
                .underline(false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isLink)
        .accessibilityRemoveTraits(.isButton)
    }
}

struct AppLink_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "AppLink") {
            AppLink(title: "Конфиденциальность", action: {})
                .padding(Theme.Space.s4)
                .background(Theme.Color.bg)
        }
    }
}
