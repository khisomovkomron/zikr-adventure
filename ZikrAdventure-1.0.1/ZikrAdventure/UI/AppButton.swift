// AppButton.swift
// Кнопки .btn / .btn.primary / .btn.danger из index.html.

import SwiftUI

struct AppButton: View {
    enum Kind {
        case primary
        case secondary
        case destructive
    }

    let title: String
    var kind: Kind = .secondary
    var icon: Image? = nil
    var isFullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(role: kind == .destructive ? .destructive : nil, action: action) {
            HStack(spacing: Theme.Space.s2) {
                if let icon {
                    icon
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Theme.Size.iconButton, height: Theme.Size.iconButton)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .themeFont(.bodyStrong)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(Theme.Scale.buttonTitle)
            }
            .padding(.horizontal, Theme.Space.controlX)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: Theme.Size.button)
        }
        .buttonStyle(AppButtonStyle(kind: kind))
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

private struct AppButtonStyle: ButtonStyle {
    let kind: AppButton.Kind
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(border, lineWidth: Theme.Size.hairline)
            )
            .opacity(configuration.isPressed ? Theme.Opacity.pressed : 1)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
    }

    private var foreground: Color {
        if !isEnabled { return Theme.Color.textDisabled }
        switch kind {
        case .primary: return Theme.Color.textOnPrimary
        case .secondary: return Theme.Color.text
        case .destructive: return Theme.Color.danger
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return Theme.Color.primary
        case .secondary, .destructive: return Theme.Color.surface
        }
    }

    private var border: Color {
        switch kind {
        case .primary: return Theme.Color.gold.opacity(Theme.Opacity.primaryBorder)
        case .secondary, .destructive: return Theme.Color.divider
        }
    }
}

struct AppButton_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "AppButton") {
            VStack(spacing: Theme.Space.s3) {
                AppButton(title: "Начать", kind: .primary, action: {})
                AppButton(title: "Закрыть", kind: .secondary, action: {})
                AppButton(title: "Сбросить", kind: .destructive, action: {})
                AppButton(title: "Неактивна", kind: .secondary, action: {}).disabled(true)
            }
            .padding(Theme.Space.s4)
            .background(Theme.Color.bg)
        }
    }
}
