// SiraChapterSheet.swift
// ZKR-53: лист главы — chapterCard(ch, withMapBtn) в index.html. Глава с местом — placeCard(place, { siraFirst }):
// значок категории, «категория · город», название, арабское название, «Справка редакции проекта», блок Сиры,
// «Значение», расстояние (distText), «Облик в VII веке», «На карте», «Закрыть». Без места — «Глава N · год»,
// заголовок, текст, «На карте» (если есть город), «Закрыть».
// Оформление листа — как InfoSheetHost (ZKR-48): затемнение .2 с, лист .26 с, 86 % высоты.

import SwiftUI
import ZikrContent

struct SiraChapterSheet: View {
    @ObservedObject var viewModel: SiraViewModel
    @ObservedObject var localization: LocalizationService
    let state: SiraChapterSheetState

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var isShown = false
    @State private var contentHeight: CGFloat = 0
    @AccessibilityFocusState private var isTitleFocused: Bool

    init(viewModel: SiraViewModel, state: SiraChapterSheetState) {
        self.viewModel = viewModel
        self.localization = viewModel.localization
        self.state = state
    }

    /// motionReduced(): системный Reduce Motion или выключенные «Анимации».
    private var reducesMotion: Bool { systemReduceMotion || !viewModel.animationsEnabled }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Theme.Color.sheetScrim
                    .ignoresSafeArea()
                    .opacity(isShown ? 1 : 0)
                    .animation(reducesMotion ? nil : Self.ease(Theme.Motion.scrimFade), value: isShown)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.closeSheet() }
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("sira.scrim")

                sheetBody(maxHeight: (proxy.size.height + proxy.safeAreaInsets.top) * Theme.Scale.sheetMaxHeight)
                    .frame(maxWidth: .infinity)
                    .background(
                        Theme.Color.bg
                            .clipShape(TopRoundedRectangle(radius: Theme.Radius.sheet))
                            .ignoresSafeArea(edges: .bottom)
                    )
                    .offset(y: isShown ? 0 : Theme.Motion.sheetUpOffset)
                    .animation(reducesMotion ? nil : Self.ease(Theme.Motion.sheetUp), value: isShown)
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { viewModel.closeSheet() }
                    .accessibilityIdentifier("sira.sheet")
            }
        }
        .onAppear {
            isShown = true
            DispatchQueue.main.async { isTitleFocused = true }
        }
    }

    private func tr(_ key: L10nKey) -> String {
        localization.tr(key)
    }

    private func sheetBody(maxHeight: CGFloat) -> some View {
        ScrollView {
            sheetContent
                .background(
                    GeometryReader { content in
                        Color.clear.preference(key: SheetContentHeightKey.self, value: content.size.height)
                    }
                )
        }
        .scrollDisabled(contentHeight <= maxHeight)
        .frame(height: min(contentHeight, maxHeight))
        .onPreferenceChange(SheetContentHeightKey.self) { contentHeight = $0 }
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Theme.Color.divider)
                .frame(width: Theme.Size.grabWidth, height: Theme.Size.grabHeight)
                .frame(maxWidth: .infinity)
                .padding(.bottom, Theme.Space.s3)
                .accessibilityHidden(true)

            if let chapter = viewModel.chapter(state.chapterID) {
                if let place = viewModel.place(chapter.place) {
                    placeContent(chapter, place)
                } else {
                    chapterContent(chapter)
                }
            }
        }
        .padding(.top, Theme.Space.sheetTop)
        .padding(.horizontal, Theme.Space.sheetX)
        .padding(.bottom, Theme.Space.s6)
    }

    // MARK: - chapterCard (глава без места)

    private func chapterContent(_ chapter: ZikrScreenContent.Chapter) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            kicker("\(localization.tr(.pathChapter, "\(viewModel.index(of: chapter.id))")) · \(viewModel.year(chapter.id))")
            title(viewModel.title(chapter.id))
                .padding(.top, Theme.Sira.titleTop)
                .padding(.bottom, Theme.Sira.titleBottom)
            Text(viewModel.text(chapter.text))
                .themeFont(.body)
                .themeLineHeight(.body, multiple: Theme.Font.bodyLineHeightMultiple)
                .foregroundColor(Theme.Color.text)
                .fixedSize(horizontal: false, vertical: true)
                // `<p>`: margin 1em сверху и снизу; сверху схлопывается с margin-bottom 4 заголовка.
                .padding(.top, Theme.Typo.body.pointSize - Theme.Sira.titleBottom)
                .padding(.bottom, Theme.Typo.body.pointSize)
                .accessibilityIdentifier("sira.sheet.text")
            if state.showsMapButton, chapter.city != nil {
                mapButton
                    .padding(.bottom, Theme.Sira.mapButtonBottom)
            }
            closeButton
        }
    }

    // MARK: - placeCard (глава с местом, siraFirst)

    private func placeContent(_ chapter: ZikrScreenContent.Chapter, _ place: ZikrScreenContent.Place) -> some View {
        let open = viewModel.isOpen(chapter.id)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: Theme.Sira.headGap) {
                glyph(place.cat)
                VStack(alignment: .leading, spacing: 0) {
                    kicker("\(name("cat", place.cat)) · \(name("city", place.city))")
                    title(viewModel.text(place.name))
                        .padding(.top, Theme.Sira.titleTop)
                        .padding(.bottom, Theme.Sira.titleBottom)
                    Text(place.ar)
                        .themeFont(.arabicName, scales: false)
                        .themeLineHeight(.arabicName, multiple: Theme.Font.bodyLineHeightMultiple)
                        .foregroundColor(Theme.Color.textSecondary)
                        .padding(.bottom, Theme.Sira.arabicBottom)
                        .accessibilityIdentifier("sira.sheet.arabic")
                    sourceBadge
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: Theme.Sira.stackGap) {
                siraBlock(chapter, place, open: open)
                VStack(alignment: .leading, spacing: 0) {
                    kicker(tr(.cardSig))
                    paragraph(viewModel.text(place.sig))
                        .padding(.top, Theme.Sira.paragraphTop)
                }
                xs(viewModel.distanceText(place))
                    .accessibilityIdentifier("sira.sheet.distance")
                VStack(alignment: .leading, spacing: 0) {
                    kicker(tr(.cardLook))
                    paragraph(viewModel.text(place.look))
                        .padding(.top, Theme.Sira.paragraphTop)
                    xs(tr(.cardLookNote))
                        .padding(.top, Theme.Sira.noteTop)
                }
                if state.showsMapButton {
                    mapButton
                }
                closeButton
            }
            .padding(.top, Theme.Sira.stackTop)
        }
    }

    /// `.sira` (открыта) или `.sira.locked`.
    @ViewBuilder
    private func siraBlock(_ chapter: ZikrScreenContent.Chapter, _ place: ZikrScreenContent.Place, open: Bool) -> some View {
        if open {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s1) {
                    icon("InfoStar", size: Theme.Sira.siraStar)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                    kicker("\(tr(.cardSira)) · \(localization.tr(.pathChapter, "\(viewModel.index(of: chapter.id))")) · \(viewModel.year(chapter.id))")
                }
                Text(viewModel.text(place.sira))
                    .themeFont(.body)
                    .themeLineHeight(.body, multiple: Theme.Font.bodyLineHeightMultiple)
                    .foregroundColor(Theme.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Theme.Sira.siraTextTop)
                    .accessibilityIdentifier("sira.sheet.sira")
            }
            .padding(.vertical, Theme.Sira.siraPaddingY)
            .padding(.horizontal, Theme.Sira.siraPaddingX)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Theme.Color.surface
                    Theme.Color.accent.opacity(Theme.Sira.siraFill)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Sira.siraRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Sira.siraRadius, style: .continuous)
                    .strokeBorder(Theme.Color.accent.opacity(Theme.Opacity.accentBorder), lineWidth: Theme.Size.hairline)
            )
        } else {
            HStack(alignment: .top, spacing: Theme.Sira.siraLockGap) {
                icon("InfoLock", size: Theme.Sira.siraLock)
                Text(localization.tr(.cardSiraLocked, localization.format(Int(clamping: chapter.n))))
                    .themeFont(.calloutRegular)
                    .themeLineHeight(.calloutRegular, multiple: Theme.Font.bodyLineHeightMultiple)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(Theme.Color.textSecondary)
            .padding(.vertical, Theme.Sira.siraPaddingY)
            .padding(.horizontal, Theme.Sira.siraPaddingX)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Color.bgSubtle)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Sira.siraRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Sira.siraRadius, style: .continuous)
                    .strokeBorder(Theme.Color.divider, lineWidth: Theme.Size.hairline)
            )
        }
    }

    /// `.glyph`: 56 × 56, accentSoft, значок категории (CAT_ICON) 28.
    private func glyph(_ category: String) -> some View {
        icon(Self.categoryIcon(category), size: Theme.Sira.glyphIcon)
            .foregroundColor(Theme.Color.accent)
            .frame(width: Theme.Sira.glyph, height: Theme.Sira.glyph)
            .background(Theme.Color.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Sira.glyphRadius, style: .continuous))
            .accessibilityHidden(true)
    }

    /// `.badge`: книга + «Справка редакции проекта», accent, фон accent 10 %, обводка currentColor.
    private var sourceBadge: some View {
        HStack(spacing: Theme.Sira.badgeGap) {
            icon("InfoBook", size: Theme.Sira.badgeIcon)
            Text(tr(.cardSource))
                .themeFont(.footnote)
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(Theme.Color.accent)
        .padding(.vertical, Theme.Sira.badgePaddingY)
        .padding(.horizontal, Theme.Sira.badgePaddingX)
        .background(Capsule().fill(Theme.Color.accent.opacity(Theme.Opacity.accentFill)))
        .overlay(Capsule().strokeBorder(Theme.Color.accent, lineWidth: Theme.Size.hairline))
        .accessibilityElement(children: .combine)
    }

    /// CAT_ICON в index.html.
    static func categoryIcon(_ category: String) -> String {
        switch category {
        case "sacred": return "SiraSacred"
        case "mosque": return "SiraMosque"
        case "sira": return "SiraScroll"
        case "nature": return "SiraMountain"
        case "memorial": return "SiraMemorial"
        default: return "InfoUrban"
        }
    }

    // MARK: - Общие элементы

    private func name(_ prefix: String, _ key: String) -> String {
        L10nKey(rawValue: "\(prefix).\(key)").map { tr($0) } ?? key
    }

    private func icon(_ name: String, size: CGFloat) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private func kicker(_ text: String) -> some View {
        Text(text)
            .themeFont(.kicker, pointSize: Theme.Sira.smallTextWeb)
            .themeLineHeight(.kicker, multiple: Theme.Font.bodyLineHeightMultiple)
            .foregroundColor(Theme.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .themeFont(.body)
            .themeLineHeight(.body, multiple: Theme.Font.bodyLineHeightMultiple)
            .foregroundColor(Theme.Color.text)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func xs(_ text: String) -> some View {
        Text(text)
            .themeFont(.xs, pointSize: Theme.Sira.smallTextWeb)
            .themeLineHeight(.xs, multiple: Theme.Font.bodyLineHeightMultiple)
            .foregroundColor(Theme.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .themeFont(.headingSheet)
            .themeLineHeight(.headingSheet, multiple: Theme.Font.sheetTitleLineHeightMultiple)
            .foregroundColor(Theme.Color.text)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($isTitleFocused)
            .accessibilityIdentifier("sira.sheet.title")
    }

    private var mapButton: some View {
        AppButton(title: tr(.pathShow), kind: .primary, icon: Image("TabMap")) {
            viewModel.exploreFromSheet()
        }
        .accessibilityIdentifier("sira.sheet.map")
    }

    private var closeButton: some View {
        AppButton(title: tr(.commonClose), kind: .secondary) {
            viewModel.closeSheet()
        }
        .accessibilityIdentifier("sira.sheet.close")
    }

    /// CSS `ease` = cubic-bezier(.25, .1, .25, 1).
    private static func ease(_ duration: Double) -> Animation {
        .timingCurve(0.25, 0.1, 0.25, 1, duration: duration)
    }
}
