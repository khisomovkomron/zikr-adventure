// ZikrView.swift
// ZKR-52: нативный экран «Зикр» — порядок и состав как renderZikr() в index.html:
// шапка «ZIKR ADVENTURE» + шестерёнка → текст зикра → счётчик → кнопка → «Исправить / Обнулить / Карта»
// → «Сегодня» (+ личная цель) → «Путь Сиры» (progressCard) → «История по дням» → примечание.
// Диалог сброса, лист истории и баннер открытия главы — поверх. Только вёрстка на UI kit (ZKR-51);
// логика — ZikrViewModel.

import SwiftUI
import ZikrDomain

struct ZikrView: View {
    @ObservedObject var viewModel: ZikrViewModel
    @ObservedObject var localization: LocalizationService
    /// Переход по data-tab (шестерёнка → «Настройки», «Карта»).
    let selectTab: (TabItem) -> Void

    init(viewModel: ZikrViewModel, selectTab: @escaping (TabItem) -> Void) {
        self.viewModel = viewModel
        self.localization = viewModel.localization
        self.selectTab = selectTab
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                if let settings = viewModel.settings {
                    content(settings)
                }
            }
            .background(Theme.Color.bg.ignoresSafeArea(edges: .top))
            .accessibilityHidden(viewModel.isHistoryPresented)

            if viewModel.isHistoryPresented {
                ZikrHistorySheet(viewModel: viewModel)
            }

            if let banner = viewModel.banner {
                ZikrUnlockBannerView(
                    banner: banner,
                    title: tr(.bannerTitle),
                    headline: banner.isSingle
                        ? viewModel.chapterTitle(banner.focusChapterID)
                        : localization.tr(.bannerMulti, localization.format(banner.chapterIDs.count)),
                    year: banner.isSingle ? viewModel.chapterYear(banner.focusChapterID) : "",
                    exploreTitle: tr(.bannerExplore),
                    closeLabel: tr(.commonClose),
                    animationsEnabled: viewModel.animationsEnabled,
                    onExplore: { viewModel.exploreBanner() },
                    onClose: { viewModel.hideBanner() }
                )
                .id(banner.id)
            }
        }
        .alert(tr(.resetTitle), isPresented: $viewModel.isResetDialogPresented) {
            Button(tr(.resetCounter), role: .destructive) { viewModel.reset(.counter) }
            Button(tr(.resetAll), role: .destructive) { viewModel.reset(.all) }
            Button(tr(.commonCancel), role: .cancel) {}
        } message: {
            Text(tr(.resetMsg))
        }
        .accessibilityIdentifier("zikr.screen")
    }

    private func tr(_ key: L10nKey) -> String {
        localization.tr(key)
    }

    private func number(_ value: Int64) -> String {
        localization.format(Int(clamping: value))
    }

    @ViewBuilder
    private func content(_ settings: AppSettings) -> some View {
        VStack(spacing: 0) {
            topBar

            VStack(spacing: 0) {
                textCard(settings)

                AppCounterDisplay(
                    value: Int(clamping: viewModel.total),
                    caption: tr(.zikrTotal),
                    formattedValue: number(viewModel.total)
                )
                .accessibilityIdentifier("zikr.total")
                .padding(.top, Theme.Zikr.counterTop)

                ZikrTapButton(
                    title: tr(.zikrButton),
                    accessibilityText: tr(.a11yButton),
                    tapCount: viewModel.tapCount,
                    animationsEnabled: viewModel.animationsEnabled,
                    action: { viewModel.tap() }
                )
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Zikr.buttonTop)
                .padding(.bottom, Theme.Zikr.buttonBottom)

                actionRow

                todayCard
                    .padding(.top, Theme.Space.s4)

                ZikrProgressCard(viewModel: viewModel, localization: localization)
                    .padding(.top, Theme.Space.s4)

                AppButton(title: tr(.zikrHistory), kind: .secondary, icon: Image("ZikrCalendar")) {
                    viewModel.openHistory()
                }
                .accessibilityIdentifier("zikr.history")
                .padding(.top, Theme.Space.s4)

                Text(tr(.zikrNote))
                    .themeFont(.footnote)
                    .foregroundColor(Theme.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Zikr.noteTop)
            }
            .padding(.top, Theme.Space.s1)
            .padding(.horizontal, Theme.Space.screenX)
            .padding(.bottom, Theme.Space.screenBottom)
        }
    }

    /// `.topbar`: h1 «ZIKR ADVENTURE» + `.icon-btn[data-tab=settings]`.
    private var topBar: some View {
        HStack(spacing: Theme.Space.s2) {
            Text("ZIKR ADVENTURE")
                .themeFont(.headingMD)
                .tracking(Theme.Zikr.titleTracking)
                .foregroundColor(Theme.Color.text)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            AppIconButton(image: Image("TabGear"), label: tr(.tabSettings)) {
                selectTab(.settings)
            }
            .accessibilityIdentifier("zikr.settings")
        }
        .padding(.top, Theme.Space.topbarTop)
        .padding(.bottom, Theme.Space.topbarBottom)
        .padding(.horizontal, Theme.Space.s4)
        .frame(maxWidth: .infinity, minHeight: Theme.Space.topbarMinHeight)
    }

    /// `.card.zikr-text`: арабский текст, транслитерация (translit), перевод (translation).
    private func textCard(_ settings: AppSettings) -> some View {
        AppCard {
            VStack(spacing: 0) {
                ZikrArabicText(text: "أَسْتَغْفِرُ اللَّهَ")
                if settings.translit {
                    Text("Astaghfirullah")
                        .themeFont(.translit)
                        .themeLineHeight(.translit, multiple: Theme.Font.bodyLineHeightMultiple)
                        .foregroundColor(Theme.Color.accent)
                        .padding(.top, Theme.Zikr.translitTop)
                        .accessibilityIdentifier("zikr.translit")
                }
                if settings.translation {
                    Text(tr(.zikrTranslation))
                        .themeFont(.body)
                        .themeLineHeight(.body, multiple: Theme.Font.bodyLineHeightMultiple)
                        .foregroundColor(Theme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Theme.Zikr.translationTop)
                        .accessibilityIdentifier("zikr.translation")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Zikr.textCardTop - Theme.Space.s4)
            .padding(.bottom, Theme.Zikr.textCardBottom - Theme.Space.s4)
        }
    }

    /// `.row3`: «Исправить» (disabled при 0), «Обнулить» (disabled при 0), «Карта».
    private var actionRow: some View {
        HStack(spacing: Theme.Zikr.actionGap) {
            ZikrActionButton(title: tr(.zikrCorrect), icon: Image("ZikrUndo")) {
                viewModel.undo()
            }
            .disabled(!viewModel.canUndoOrReset)
            .accessibilityLabel(tr(.a11yCorrect))
            .accessibilityIdentifier("zikr.undo")

            ZikrActionButton(title: tr(.zikrReset), icon: Image("ZikrZero")) {
                viewModel.requestReset()
            }
            .disabled(!viewModel.canUndoOrReset)
            .accessibilityIdentifier("zikr.reset")

            ZikrActionButton(title: tr(.zikrMap), icon: Image("TabMap")) {
                selectTab(.map)
            }
            .accessibilityIdentifier("zikr.map")
        }
    }

    /// Карточка «Сегодня»: сегодня / за сеанс и goalCard().
    private var todayCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 0) {
                AppSectionHeader(title: tr(.zikrToday), style: .sectionTitle)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(number(viewModel.today))
                            .themeFont(.statLarge)
                            .monospacedDigit()
                            .foregroundColor(Theme.Color.text)
                        Text(tr(.zikrTodayCap))
                            .themeFont(.xs)
                            .foregroundColor(Theme.Color.textSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(tr(.zikrTodayCap))
                    .accessibilityValue(number(viewModel.today))
                    .accessibilityIdentifier("zikr.today")
                    Spacer(minLength: Theme.Space.s2)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(number(viewModel.session))
                            .themeFont(.statMedium)
                            .monospacedDigit()
                            .foregroundColor(Theme.Color.text)
                        Text(tr(.zikrSession))
                            .themeFont(.xs)
                            .foregroundColor(Theme.Color.textSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(tr(.zikrSession))
                    .accessibilityValue(number(viewModel.session))
                    .accessibilityIdentifier("zikr.session")
                }
                if let goal = viewModel.goal {
                    let label = localization.tr(.zikrGoal, number(goal.done), number(goal.goal))
                    AppProgressBar(progress: goal.fraction, label: label)
                        .padding(.top, Theme.Zikr.barTop)
                        .padding(.bottom, Theme.Zikr.barBottom)
                        .accessibilityHidden(true)
                    Text(label)
                        .themeFont(.xs)
                        .foregroundColor(Theme.Color.textSecondary)
                        .accessibilityIdentifier("zikr.goal")
                }
            }
        }
    }
}

/// `.arabic`: Geeza Pro, clamp(38px, 11vw, 50px), line-height 1.5, справа налево; без Dynamic Type, как в вебе.
private struct ZikrArabicText: View {
    let text: String
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        let size = Theme.Zikr.arabicSize(width: Theme.Size.viewportWidth)
        let font = Theme.Font.scaledUIFont(.arabic, pointSize: size, sizeCategory: sizeCategory, scales: false)
        Text(text)
            .font(Font(font))
            .foregroundColor(Theme.Color.text)
            .multilineTextAlignment(.center)
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.vertical, max(0, size * Theme.Zikr.arabicLineHeight - font.lineHeight) / 2)
            .accessibilityIdentifier("zikr.arabic")
    }
}

/// `.row3 .btn`: иконка над подписью, padding 8 6, min-height 60.
private struct ZikrActionButton: View {
    let title: String
    let icon: Image
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Zikr.actionIconGap) {
                icon
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.Size.iconButton, height: Theme.Size.iconButton)
                    .accessibilityHidden(true)
                Text(title)
                    .themeFont(.actionLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.vertical, Theme.Zikr.actionPaddingY)
            .padding(.horizontal, Theme.Zikr.actionPaddingX)
            .frame(maxWidth: .infinity, minHeight: Theme.Zikr.actionMinHeight)
        }
        .buttonStyle(ZikrActionButtonStyle())
        .accessibilityLabel(title)
    }
}

private struct ZikrActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? Theme.Color.text : Theme.Color.textDisabled)
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Theme.Color.divider, lineWidth: Theme.Size.hairline)
            )
            .opacity(configuration.isPressed ? Theme.Opacity.pressed : 1)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
    }
}
