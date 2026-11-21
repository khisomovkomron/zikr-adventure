// SiraView.swift
// ZKR-53: нативный экран «Путь Сиры» — порядок и состав как renderPath() в index.html:
// шапка «Путь Сиры» → карточка прогресса (progressCard(), общая с «Зикром») → примечание path.footer
// → 7 уровней: заголовок `.lvl-head` (★ / номер, «Уровень N · название», «from – to») и лента глав `.timeline`
// (точка ★ / номер, «год · город», название + «Новое», «Глава открыта» / «Откроется на N», «Читать» и «На карте»).
// Лист главы — SiraChapterSheet. Только вёрстка на UI kit; логика — SiraViewModel.

import SwiftUI
import ZikrContent
import ZikrDomain

struct SiraView: View {
    @ObservedObject var viewModel: SiraViewModel
    /// Карточка прогресса — та же модель, что у экрана «Зикр» (progressCard() в обоих экранах).
    @ObservedObject var progress: ZikrViewModel
    @ObservedObject var localization: LocalizationService

    init(viewModel: SiraViewModel, progress: ZikrViewModel) {
        self.viewModel = viewModel
        self.progress = progress
        self.localization = viewModel.localization
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                content
            }
            .background(Theme.Color.bg.ignoresSafeArea(edges: .top))
            .accessibilityHidden(viewModel.sheet != nil)

            if let sheet = viewModel.sheet {
                SiraChapterSheet(viewModel: viewModel, state: sheet)
                    .id(sheet.id)
            }
        }
        .onAppear { viewModel.didAppear() }
        .onDisappear { viewModel.didDisappear() }
        .accessibilityIdentifier("sira.screen")
    }

    private func tr(_ key: L10nKey) -> String {
        localization.tr(key)
    }

    private func number(_ value: Int64) -> String {
        localization.format(Int(clamping: value))
    }

    private var content: some View {
        VStack(spacing: 0) {
            topBar

            VStack(alignment: .leading, spacing: 0) {
                ZikrProgressCard(viewModel: progress, localization: localization, usesWebLineHeights: true)

                Text(tr(.pathFooter))
                    .themeFont(.footnote)
                    .themeLineHeight(.footnote, multiple: Theme.Font.bodyLineHeightMultiple)
                    .foregroundColor(Theme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Theme.Sira.footTop)
                    .padding(.horizontal, Theme.Sira.footX)
                    .accessibilityIdentifier("sira.footer")

                ForEach(viewModel.groups, id: \.index) { group in
                    levelHeader(group)
                        .padding(.top, Theme.Sira.levelTop)
                    timeline(group)
                        .padding(.top, Theme.Sira.timelineTop)
                        .padding(.bottom, Theme.Sira.timelineBottom)
                }
            }
            .padding(.top, Theme.Space.s1)
            .padding(.horizontal, Theme.Space.screenX)
            .padding(.bottom, Theme.Space.screenBottom)
        }
    }

    /// `.topbar` + `h1` «Путь Сиры».
    private var topBar: some View {
        HStack(spacing: Theme.Space.s2) {
            Text(tr(.pathTitle))
                .themeFont(.headingMD)
                .tracking(Theme.Zikr.titleTracking)
                .foregroundColor(Theme.Color.text)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("sira.title")
            Spacer(minLength: 0)
        }
        .padding(.top, Theme.Space.topbarTop)
        .padding(.bottom, Theme.Space.topbarBottom)
        .padding(.horizontal, Theme.Space.s4)
        .frame(maxWidth: .infinity, minHeight: Theme.Space.topbarMinHeight)
    }

    // MARK: - Уровень

    /// `.lvl-head` (+ `.done` / `.active`).
    private func levelHeader(_ group: SiraJourney.Group) -> some View {
        HStack(spacing: Theme.Sira.levelGap) {
            levelBadge(group)
            VStack(alignment: .leading, spacing: 0) {
                Text(localization.tr(.levelHead, localization.format(group.number), viewModel.levelName(group.index)))
                    .themeFont(.levelHead)
                    .themeLineHeight(.levelHead, multiple: Theme.Font.bodyLineHeightMultiple)
                    .foregroundColor(Theme.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(number(group.bounds.from)) – \(number(group.bounds.to))")
                    .themeFont(.xs, pointSize: Theme.Sira.smallTextWeb)
                    .themeLineHeight(.xs, multiple: Theme.Font.bodyLineHeightMultiple)
                    .foregroundColor(Theme.Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Theme.Sira.levelPaddingY)
        .padding(.horizontal, Theme.Sira.levelPaddingX)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.bgSubtle)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Sira.levelRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("sira.level.\(group.number)")
    }

    private func levelBadge(_ group: SiraJourney.Group) -> some View {
        let fill: Color, text: Color, border: Color
        switch group.state {
        case .done: (fill, text, border) = (Theme.Color.siraGold, Theme.Color.siraInk, Theme.Color.siraGold)
        case .active: (fill, text, border) = (Theme.Color.primary, Theme.Color.goldLight, Theme.Color.gold)
        case .upcoming: (fill, text, border) = (Theme.Color.surface, Theme.Color.textSecondary, Theme.Color.divider)
        }
        return Text(group.state == .done ? "★" : "\(group.number)")
            .themeFont(.levelHeadBadge, scales: false)
            .foregroundColor(text)
            .frame(width: Theme.Sira.levelBadge, height: Theme.Sira.levelBadge)
            .background(Circle().fill(fill))
            .overlay(Circle().strokeBorder(border, lineWidth: Theme.Sira.levelBadgeBorder))
            .accessibilityHidden(true)
    }

    // MARK: - Лента глав

    /// `.timeline`: вертикальная линия под точками и строки `.tl`.
    private func timeline(_ group: SiraJourney.Group) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(group.chapterIDs, id: \.self) { id in
                row(id)
            }
        }
        .padding(.leading, Theme.Sira.timelineLeading)
        .background(alignment: .topLeading) {
            GeometryReader { proxy in
                Theme.Color.divider
                    .frame(width: Theme.Sira.lineWidth, height: max(0, proxy.size.height - 2 * Theme.Sira.lineInset))
                    .offset(x: Theme.Sira.lineX, y: Theme.Sira.lineInset)
            }
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func row(_ id: String) -> some View {
        if let chapter = viewModel.chapter(id) {
            let on = viewModel.isOpen(id)
            HStack(alignment: .top, spacing: Theme.Sira.rowGap) {
                dot(index: viewModel.index(of: id), on: on)
                rowBody(chapter, on: on)
            }
            .padding(.vertical, Theme.Sira.rowPaddingY)
        }
    }

    /// `.tl .dot` / `.tl.on .dot`.
    private func dot(index: Int, on: Bool) -> some View {
        ZStack {
            if on {
                Image("InfoStar")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.Sira.dotStar, height: Theme.Sira.dotStar)
            } else {
                Text("\(index)")
                    .themeFont(.timelineDot, scales: false)
            }
        }
        .foregroundColor(on ? Theme.Color.siraInk : Theme.Color.textSecondary)
        .frame(width: Theme.Sira.dot, height: Theme.Sira.dot)
        .background(Circle().fill(on ? Theme.Color.siraGold : Theme.Color.surface))
        .overlay(Circle().strokeBorder(on ? Theme.Color.siraGold : Theme.Color.divider, lineWidth: Theme.Sira.dotBorder))
        .accessibilityHidden(true)
    }

    /// `.tl-body`: «год · город», название (+ `.newb`), статус и кнопки открытой главы.
    private func rowBody(_ chapter: ZikrScreenContent.Chapter, on: Bool) -> some View {
        let id = chapter.id
        let isNew = viewModel.isNew(id)
        let kicker = viewModel.year(id) + (chapter.city.map { " · " + cityName($0) } ?? "")
        let status = on ? tr(.pathIsOpen) : localization.tr(.pathOpensAt, number(chapter.n))
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(kicker)
                    .themeFont(.kicker, pointSize: Theme.Sira.smallTextWeb)
                    .themeLineHeight(.kicker, multiple: Theme.Font.bodyLineHeightMultiple)
                    .foregroundColor(Theme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                SiraTimelineTitle(
                    title: viewModel.title(id),
                    newLabel: isNew ? tr(.pathNew) : nil,
                    color: on ? Theme.Color.text : Theme.Color.textSecondary
                )
                Text(status)
                    .themeFont(.xs, pointSize: Theme.Sira.smallTextWeb)
                    .themeLineHeight(.xs, multiple: Theme.Font.bodyLineHeightMultiple)
                    .foregroundColor(Theme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([kicker, viewModel.title(id), isNew ? tr(.pathNew) : nil, status].compactMap { $0 }.joined(separator: ", "))
            .accessibilityIdentifier("sira.chapter.\(id)")
            .accessibilityValue(isNew ? "new" : (on ? "open" : "locked"))

            if on {
                HStack(spacing: Theme.Sira.chipsGap) {
                    SiraChipButton(title: tr(.pathRead), isGhost: false) { viewModel.read(id) }
                        .accessibilityIdentifier("sira.read.\(id)")
                    if chapter.city != nil {
                        SiraChipButton(title: tr(.pathShow), isGhost: true) { viewModel.showOnMap(id) }
                            .accessibilityIdentifier("sira.map.\(id)")
                    }
                }
                .padding(.top, Theme.Sira.chipsTop)
            }
        }
        .padding(.vertical, Theme.Sira.bodyPaddingY)
        .padding(.horizontal, Theme.Sira.bodyPaddingX)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Sira.bodyRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Sira.bodyRadius, style: .continuous)
                .strokeBorder(on ? Theme.Color.accent.opacity(Theme.Sira.bodyBorderOpen) : Theme.Color.divider, lineWidth: Theme.Size.hairline)
        )
        .accessibilityElement(children: .contain)
    }

    private func cityName(_ city: String) -> String {
        L10nKey(rawValue: "city.\(city)").map { tr($0) } ?? city
    }
}

/// `.chip-btn` (navy) и `.chip-btn.ghost` (прозрачная, обводка divider).
struct SiraChipButton: View {
    let title: String
    let isGhost: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .themeFont(.chipButton)
                .lineLimit(1)
                .foregroundColor(isGhost ? Theme.Color.text : Theme.Color.textOnPrimary)
                .padding(.vertical, Theme.Zikr.chipPaddingY)
                .padding(.horizontal, Theme.Zikr.chipPaddingX)
                .frame(minHeight: Theme.Size.chip)
                .background(isGhost ? Color.clear : Theme.Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chipButton, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.chipButton, style: .continuous)
                        .strokeBorder(isGhost ? Theme.Color.divider : Color.clear, lineWidth: Theme.Size.hairline)
                )
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.chipButton, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// `.tl-title` (serif 18/600, line-height 1.25) с меткой `.newb` в конце строки, как inline-block в вебе:
/// метка — картинка внутри Text, поэтому переносится вместе с последним словом.
struct SiraTimelineTitle: View {
    let title: String
    let newLabel: String?
    let color: Color

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        textView
            .themeFont(.timelineTitle)
            .themeLineHeight(.timelineTitle, multiple: Theme.Sira.titleLineHeight)
            .foregroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var textView: Text {
        guard let newLabel else { return Text(title) }
        let badge = SiraNewBadgeRenderer.render(
            newLabel,
            colorScheme: colorScheme,
            sizeCategory: sizeCategory,
            scale: displayScale
        )
        return Text(title) + Text(Image(uiImage: badge.image)).baselineOffset(badge.baselineOffset)
    }
}

/// `.newb`: accentSoft, 12.5/700, padding 1 8, margin-left 6, vertical-align 2px, line-height 1.25 (из .tl-title).
enum SiraNewBadgeRenderer {
    struct Badge {
        let image: UIImage
        let baselineOffset: CGFloat
    }

    static func render(_ text: String, colorScheme: ColorScheme, sizeCategory: ContentSizeCategory, scale: CGFloat) -> Badge {
        let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let font = Theme.Font.scaledUIFont(.newBadge, sizeCategory: sizeCategory)
        let fill = (UIColor(named: "AccentSoft") ?? .systemYellow).resolvedColor(with: traits)
        let ink = (UIColor(named: "Text") ?? .label).resolvedColor(with: traits)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let lineBox = font.pointSize * Theme.Sira.titleLineHeight
        let halfLeading = (lineBox - font.lineHeight) / 2
        let pill = CGSize(width: ceil(textSize.width) + 2 * Theme.Sira.newPaddingX, height: lineBox + 2 * Theme.Sira.newPaddingY)
        let size = CGSize(width: pill.width + Theme.Sira.newLeading, height: pill.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let rect = CGRect(x: Theme.Sira.newLeading, y: 0, width: pill.width, height: pill.height)
            fill.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: pill.height / 2).fill()
            let origin = CGPoint(x: rect.minX + Theme.Sira.newPaddingX, y: Theme.Sira.newPaddingY + halfLeading)
            (text as NSString).draw(at: origin, withAttributes: attributes)
        }
        // Базовая линия текста метки = базовая линия строки, поднятая на 2 pt (vertical-align: 2px).
        let baselineFromBottom = Theme.Sira.newPaddingY + halfLeading - font.descender
        return Badge(image: image.withRenderingMode(.alwaysOriginal), baselineOffset: Theme.Sira.newRaise - baselineFromBottom)
    }
}
