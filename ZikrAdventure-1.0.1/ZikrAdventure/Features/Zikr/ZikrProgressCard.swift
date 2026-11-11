// ZikrProgressCard.swift
// ZKR-52: карточка «Путь Сиры» — progressCard() в index.html: бейдж уровня (или ★), «Уровень N из 7»,
// название уровня, шкала from–to, «До следующего уровня», следующая глава и «Открыто глав: X из Y».

import SwiftUI
import ZikrDomain

struct ZikrProgressCard: View {
    @ObservedObject var viewModel: ZikrViewModel
    @ObservedObject var localization: LocalizationService

    var body: some View {
        let card = viewModel.levelCard
        AppCard {
            VStack(alignment: .leading, spacing: 0) {
                AppSectionHeader(title: tr(.pathTitle), style: .sectionTitle)

                HStack(spacing: Theme.Zikr.levelRowGap) {
                    levelBadge(card)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(card.isDone ? tr(.levelDone) : localization.tr(.levelOf, number(card.number), number(card.count)))
                            .themeFont(.kickerMedium)
                            .foregroundColor(Theme.Color.textSecondary)
                        Text(viewModel.levelName(card.index))
                            .themeFont(.headingSM)
                            .foregroundColor(Theme.Color.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Theme.Zikr.chapterTitleTop)
                            .accessibilityIdentifier("zikr.level.name")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("zikr.level")

                AppProgressBar(progress: card.fraction, label: tr(.pathTitle))
                    .animation(.easeInOut(duration: Theme.Zikr.barDuration), value: card.fraction)
                    .padding(.top, Theme.Zikr.barTop)
                    .padding(.bottom, Theme.Zikr.barBottom)

                HStack {
                    Text(number(card.bounds.from))
                    Spacer()
                    Text(number(card.bounds.to))
                }
                .themeFont(.xs)
                .monospacedDigit()
                .foregroundColor(Theme.Color.textSecondary)
                .padding(.top, Theme.Zikr.scaleTop)
                .padding(.bottom, Theme.Zikr.scaleBottom)

                if !card.isDone {
                    xs(localization.tr(.levelToNext, number(card.toNext)))
                        .accessibilityIdentifier("zikr.level.toNext")
                }

                if let next = viewModel.nextChapter {
                    VStack(alignment: .leading, spacing: Theme.Zikr.nextChapterGap) {
                        Text("\(tr(.pathNext)) · \(viewModel.chapterYear(next.id))")
                            .themeFont(.kickerMedium)
                            .foregroundColor(Theme.Color.textSecondary)
                        Text(viewModel.chapterTitle(next.id))
                            .themeFont(.headingBody)
                            .foregroundColor(Theme.Color.text)
                            .fixedSize(horizontal: false, vertical: true)
                        xs(localization.tr(.pathRemaining, number(next.remaining)))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Zikr.nextChapterTop)
                    .overlay(alignment: .top) {
                        Theme.Color.divider.frame(height: Theme.Size.hairline)
                    }
                    .padding(.top, Theme.Zikr.nextChapterTop)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("zikr.nextChapter")
                }

                xs(localization.tr(.pathOpened, number(Int64(viewModel.openedCount)), number(Int64(viewModel.chapterCount))))
                    .padding(.top, Theme.Zikr.openedTop)
                    .accessibilityIdentifier("zikr.opened")
            }
        }
    }

    private func tr(_ key: L10nKey) -> String {
        localization.tr(key)
    }

    private func number(_ value: Int64) -> String {
        localization.format(Int(clamping: value))
    }

    private func number(_ value: Int) -> String {
        localization.format(value)
    }

    private func xs(_ text: String) -> some View {
        Text(text)
            .themeFont(.xs)
            .foregroundColor(Theme.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// `.lvl-badge`: 38 × 38, navy, золотая обводка 2, цифра GoldLight (★ — все уровни пройдены).
    private func levelBadge(_ card: ZikrProgress.LevelCard) -> some View {
        Text(card.isDone ? "★" : number(card.number))
            .themeFont(.levelBadge, scales: false)
            .foregroundColor(Theme.Color.goldLight)
            .frame(width: Theme.Zikr.levelBadge, height: Theme.Zikr.levelBadge)
            .background(Circle().fill(Theme.Color.primary))
            .overlay(Circle().strokeBorder(Theme.Color.gold, lineWidth: Theme.Zikr.levelBadgeBorder))
            .accessibilityHidden(true)
    }
}
