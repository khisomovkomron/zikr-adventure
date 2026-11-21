// AppCard.swift
// Карточка .card: surface, divider, radius.card, shadow.card, padding 16.

import SwiftUI

struct AppCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Color.divider, lineWidth: Theme.Size.hairline)
            )
            .themeShadow(.card)
            .accessibilityElement(children: .contain)
    }
}

struct AppCard_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "AppCard") {
            AppCard {
                VStack(alignment: .leading, spacing: Theme.Space.s2) {
                    Text("Сегодня")
                        .themeFont(.headingSM)
                        .foregroundColor(Theme.Color.text)
                    Text("повторений сегодня")
                        .themeFont(.footnote)
                        .foregroundColor(Theme.Color.textSecondary)
                }
            }
            .padding(Theme.Space.s4)
            .background(Theme.Color.bg)
        }
    }
}
