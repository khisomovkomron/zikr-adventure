// AppIconButton.swift
// Круглая кнопка .icon-btn (44×44, иконка 20).

import SwiftUI

struct AppIconButton: View {
    let systemName: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Theme.Size.iconMd, height: Theme.Size.iconMd)
                .foregroundColor(Theme.Color.text)
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .background(Theme.Color.surface)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(Theme.Color.divider, lineWidth: Theme.Size.hairline)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

struct AppIconButton_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "AppIconButton") {
            HStack(spacing: Theme.Space.s3) {
                AppIconButton(systemName: "chevron.left", label: "Назад", action: {})
                AppIconButton(systemName: "gearshape", label: "Настройки", action: {})
            }
            .padding(Theme.Space.s4)
            .background(Theme.Color.bg)
        }
    }
}
