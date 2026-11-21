// ZikrUnlockBannerView.swift
// ZKR-52: баннер `.banner` из showBanner(): «Открыта новая глава Сиры», название (или «Открыто новых глав: N»),
// год (одна глава), кнопка «Изучить» и закрытие. Появление drop .3 с (−14 pt); авто-скрытие 7 с — в ZikrViewModel.

import SwiftUI

struct ZikrUnlockBannerView: View {
    let banner: ZikrUnlockBanner
    let title: String
    let headline: String
    let year: String
    let exploreTitle: String
    let closeLabel: String
    let animationsEnabled: Bool
    let onExplore: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var isShown = false

    private var reducesMotion: Bool { systemReduceMotion || !animationsEnabled }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Zikr.bannerGap) {
            Image("ZikrStar")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Theme.Size.iconMd, height: Theme.Size.iconMd)
                .foregroundColor(Theme.Color.accent)
                .frame(width: Theme.Zikr.bannerIcon, height: Theme.Zikr.bannerIcon)
                .background(Circle().fill(Theme.Color.accentSoft))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .themeFont(.footnote)
                    .foregroundColor(Theme.Color.textSecondary)
                Text(headline)
                    .themeFont(.bannerTitle)
                    .foregroundColor(Theme.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("zikr.banner.headline")
                if !year.isEmpty {
                    Text(year)
                        .themeFont(.xs)
                        .foregroundColor(Theme.Color.textSecondary)
                }
                Button(action: onExplore) {
                    Text(exploreTitle)
                        .themeFont(.chipButton)
                        .foregroundColor(Theme.Color.textOnPrimary)
                        .padding(.vertical, Theme.Zikr.chipPaddingY)
                        .padding(.horizontal, Theme.Zikr.chipPaddingX)
                        .frame(minHeight: Theme.Size.chip)
                        .background(Theme.Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chipButton, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Zikr.chipTop)
                .accessibilityIdentifier("zikr.banner.explore")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onClose) {
                Image("ZikrClose")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.Size.iconMd, height: Theme.Size.iconMd)
                    .foregroundColor(Theme.Color.text)
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(closeLabel)
            .accessibilityIdentifier("zikr.banner.close")
        }
        .padding(.top, Theme.Zikr.bannerPaddingTop)
        .padding(.trailing, Theme.Zikr.bannerPaddingTrailing)
        .padding(.bottom, Theme.Zikr.bannerPaddingBottom)
        .padding(.leading, Theme.Zikr.bannerPaddingLeading)
        .background(Theme.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Color.accent.opacity(Theme.Opacity.accentBorder), lineWidth: Theme.Size.hairline)
        )
        .themeShadow(.overlay)
        .padding(.horizontal, Theme.Zikr.bannerInset)
        .padding(.top, Theme.Zikr.bannerTop)
        .offset(y: isShown ? 0 : -Theme.Zikr.bannerDropOffset)
        .opacity(isShown ? 1 : 0)
        .onAppear {
            if reducesMotion {
                isShown = true
            } else {
                withAnimation(.easeInOut(duration: Theme.Zikr.bannerDrop)) { isShown = true }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("zikr.banner")
    }
}
