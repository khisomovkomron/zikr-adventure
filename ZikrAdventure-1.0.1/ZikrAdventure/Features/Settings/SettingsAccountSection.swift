// SettingsAccountSection.swift
// ZKR-50: блок «Аккаунт» — копия accountHTML из renderSettings() (IS_APP):
// guest / signingIn / signedIn / error / deleting и строка «Конфиденциальность» под карточкой.
// ZKR-56: ошибка удаления (отзыв Apple, сеть) показывается в карточке с кнопкой «Повторить».

import SwiftUI

struct SettingsAccountSection: View {
    let state: SettingsAccountState
    let deletionIssueKey: L10nKey?
    let tr: (L10nKey) -> String
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onSignOut: () -> Void
    let onDelete: () -> Void
    let onRetryDeletion: () -> Void
    let onPrivacy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppSectionHeader(title: tr(.authTitle))
            AppCard {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
            }
            .accessibilityIdentifier("auth.card")

            // .list style="margin-top:12px"
            AppList {
                AppListRow(
                    title: tr(.infoPrivacy),
                    kind: .icon,
                    icon: Image("InfoLock"),
                    showsTopDivider: false,
                    action: onPrivacy
                )
                .accessibilityIdentifier("settings.privacy")
            }
            .padding(.top, Theme.Space.s3)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .guest:
            Text(tr(.authGuest))
                .themeFont(.body)
                .foregroundColor(Theme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(tr(.authIntro))
                .themeFont(.body)
                .foregroundColor(Theme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Space.s2)
            providerButtons(enabled: true)
            AppFootnote(text: tr(.authLocal))

        case .signingIn:
            AuthStatusBox(text: tr(.authLoading), style: .loading)
            providerButtons(enabled: false)

        case .signedIn(let name, let providerKey, let email):
            Text(name ?? tr(.authSigned))
                .themeFont(.body)
                .foregroundColor(Theme.Color.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AuthMetrics.userTop)
                .padding(.bottom, AuthMetrics.userBottom)
                .accessibilityIdentifier("auth.user")
            Text(email.map { "\(tr(providerKey)) · \($0)" } ?? tr(providerKey))
                .themeFont(.calloutRegular)
                .foregroundColor(Theme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            AppFootnote(text: tr(.authLocal))
            if let deletionIssueKey {
                AuthStatusBox(text: tr(deletionIssueKey), style: .error)
                    .accessibilityIdentifier("auth.deletionError")
                AppButton(title: tr(.authRetry), action: onRetryDeletion)
                    .accessibilityIdentifier("auth.retry")
            }
            // .list style="margin-top:16px"
            AppList {
                AppListRow(title: tr(.authOut), showsTopDivider: false, action: onSignOut)
                    .accessibilityIdentifier("auth.out")
                AppListRow(title: tr(.authDelete), kind: .destructive, action: onDelete)
                    .accessibilityIdentifier("auth.delete")
            }
            .padding(.top, Theme.Space.s4)

        case .error(let message, let note):
            AuthStatusBox(text: tr(message), style: .error)
                .accessibilityIdentifier("auth.status")
            if let note {
                AppFootnote(text: tr(note))
            }
            providerButtons(enabled: true)

        case .deleting:
            AuthStatusBox(text: tr(.authDeleting), style: .loading)
                .accessibilityIdentifier("auth.status")
        }
    }

    @ViewBuilder
    private func providerButtons(enabled: Bool) -> some View {
        AuthProviderButton(provider: .apple, title: tr(.authApple), action: onApple)
            .disabled(!enabled)
            .accessibilityIdentifier("auth.apple")
        AuthProviderButton(provider: .google, title: tr(.authGoogle), action: onGoogle)
            .disabled(!enabled)
            .accessibilityIdentifier("auth.google")
    }
}

private enum AuthMetrics {
    /// .auth-user{margin:14px 0 10px}
    static let userTop: CGFloat = 14
    static let userBottom: CGFloat = 10
    /// .auth-provider{min-height:52px;border-radius:10px;gap:10px;margin:8px 0}
    static let providerHeight: CGFloat = 52
    static let providerRadius: CGFloat = 10
    static let providerGap: CGFloat = 10
    static let providerIcon: CGFloat = 20
    static let disabledOpacity: Double = 0.5
}

/// .auth-loading / .auth-error: padding 12, radius 12, margin 12 0.
private struct AuthStatusBox: View {
    enum Style { case loading, error }

    let text: String
    let style: Style

    var body: some View {
        Text(text)
            .themeFont(.body)
            .foregroundColor(style == .error ? Theme.Color.warning : Theme.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.s3)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(style == .error ? Theme.Color.warning : .clear, lineWidth: Theme.Size.hairline)
            )
            .padding(.vertical, Theme.Space.s3)
            // role="status" / role="alert"
            .accessibilityAddTraits(style == .loading ? .updatesFrequently : [])
    }
}

/// Кнопки входа: фирменные цвета Apple и Google — как .auth-provider в index.html
/// (не токены Theme: требования провайдеров к виду кнопок).
private struct AuthProviderButton: View {
    enum Provider { case apple, google }

    let provider: Provider
    let title: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: AuthMetrics.providerGap) {
                icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: AuthMetrics.providerIcon, height: AuthMetrics.providerIcon)
                    .accessibilityHidden(true)
                Text(title)
                    .themeFont(.chip)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity, minHeight: AuthMetrics.providerHeight)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: AuthMetrics.providerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AuthMetrics.providerRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: provider == .google ? Theme.Size.hairline : 0)
            )
            .opacity(isEnabled ? 1 : AuthMetrics.disabledOpacity)
        }
        .buttonStyle(.plain)
        .padding(.vertical, Theme.Space.s2)
        .accessibilityLabel(title)
    }

    private var icon: Image {
        switch provider {
        case .apple: return Image("AuthApple").renderingMode(.template)
        case .google: return Image("AuthGoogle").renderingMode(.original)
        }
    }

    private var foreground: Color {
        switch provider {
        case .apple: return Self.dynamic(light: 0xFFFFFF, dark: 0x000000)
        case .google: return Self.dynamic(light: 0x202124, dark: 0xE8EAED)
        }
    }

    private var background: Color {
        switch provider {
        case .apple: return Self.dynamic(light: 0x000000, dark: 0xFFFFFF)
        case .google: return Self.dynamic(light: 0xFFFFFF, dark: 0x2D2E30)
        }
    }

    private var border: Color {
        Self.dynamic(light: 0xDADCE0, dark: 0x5F6368)
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
