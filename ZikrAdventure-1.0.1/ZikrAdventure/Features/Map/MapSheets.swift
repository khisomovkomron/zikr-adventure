// MapSheets.swift
// ZKR-57: листы «Карты» — objectCard(o), openPlaceList(city) и openLegend() в index.html.
// Оформление — как SiraChapterSheet / InfoSheetHost: затемнение .2 с, лист .26 с, 86 % высоты, «Закрыть».

import SwiftUI
import ZikrContent

/// Общая рамка листа openSheet(): затемнение, ручка, прокрутка, если не влезает.
struct MapSheetContainer<Content: View>: View {
    @ObservedObject var viewModel: MapViewModel
    let identifier: String
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var isShown = false
    @State private var contentHeight: CGFloat = 0

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
                    .accessibilityIdentifier("map.scrim")

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
                    .accessibilityIdentifier(identifier)
            }
        }
        .onAppear { isShown = true }
    }

    private func sheetBody(maxHeight: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(Theme.Color.divider)
                    .frame(width: Theme.Size.grabWidth, height: Theme.Size.grabHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Theme.Space.s3)
                    .accessibilityHidden(true)
                content
            }
            .padding(.top, Theme.Space.sheetTop)
            .padding(.horizontal, Theme.Space.sheetX)
            .padding(.bottom, Theme.Space.s6)
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

    private static func ease(_ duration: Double) -> Animation {
        .timingCurve(0.25, 0.1, 0.25, 1, duration: duration)
    }
}

/// Общие элементы листов карты.
@MainActor
private enum MapSheetParts {
    static func title(_ text: String) -> some View {
        Text(text)
            .themeFont(.headingSheet)
            .themeLineHeight(.headingSheet, multiple: Theme.Font.sheetTitleLineHeightMultiple)
            .foregroundColor(Theme.Color.text)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Theme.Sira.titleTop)
            .padding(.bottom, Theme.Sira.titleBottom)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("map.sheet.title")
    }

    /// `.group-h`: serif 19 / 600, margin 22 4 8.
    static func group(_ text: String, top: CGFloat) -> some View {
        Text(text)
            .themeFont(.headingSM)
            .foregroundColor(Theme.Color.text)
            .padding(.top, top)
            .padding(.bottom, Theme.Map.groupBottom)
            .padding(.horizontal, Theme.Map.groupX)
            .accessibilityAddTraits(.isHeader)
    }

    static func icon(_ name: String, size: CGFloat) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    static func close(_ viewModel: MapViewModel) -> some View {
        AppButton(title: viewModel.localization.tr(.commonClose), kind: .secondary) { viewModel.closeSheet() }
            .accessibilityIdentifier("map.sheet.close")
    }
}

/// objectCard(o): значок категории, «категория», название, «Условный элемент…», «Появилось с главой…».
struct MapObjectSheet: View {
    @ObservedObject var viewModel: MapViewModel
    let object: MapContent.Object

    var body: some View {
        let localization = viewModel.localization
        MapSheetContainer(viewModel: viewModel, identifier: "map.sheet.object") {
            HStack(alignment: .top, spacing: Theme.Sira.headGap) {
                MapSheetParts.icon(SiraCategoryIcon.name(object.cat ?? "city"), size: Theme.Sira.glyphIcon)
                    .foregroundColor(Theme.Color.accent)
                    .frame(width: Theme.Sira.glyph, height: Theme.Sira.glyph)
                    .background(Theme.Color.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Sira.glyphRadius, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10nKey(rawValue: "cat.\(object.cat ?? "city")").map { localization.tr($0) } ?? "")
                        .themeFont(.kicker, pointSize: Theme.Sira.smallTextWeb)
                        .foregroundColor(Theme.Color.textSecondary)
                    MapSheetParts.title(viewModel.objectName(object))
                }
            }
            VStack(alignment: .leading, spacing: Theme.Sira.stackGap) {
                Text(localization.tr(.objStylized))
                    .themeFont(.body)
                    .themeLineHeight(.body, multiple: Theme.Font.bodyLineHeightMultiple)
                    .foregroundColor(Theme.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let layer = object.layer, viewModel.chapter(layer) != nil {
                    Text(localization.tr(.objFromChapter, viewModel.title(layer)))
                        .themeFont(.xs, pointSize: Theme.Sira.smallTextWeb)
                        .foregroundColor(Theme.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("map.sheet.object.chapter")
                }
                MapSheetParts.close(viewModel)
            }
            .padding(.top, Theme.Map.objectStackTop)
        }
    }
}

/// openPlaceList(city): «Исторические места» (★ — глава открыта, иначе значок категории; «Глава N · …»)
/// и «Городская среда» (до 12 видимых объектов со слоем главы).
struct MapPlaceListSheet: View {
    @ObservedObject var viewModel: MapViewModel
    let cityID: String

    var body: some View {
        let localization = viewModel.localization
        let places = viewModel.listPlaces(city: cityID)
        let life = viewModel.listLife(city: cityID)
        MapSheetContainer(viewModel: viewModel, identifier: "map.sheet.list") {
            MapSheetParts.title(localization.tr(.mapList))
            MapSheetParts.group(localization.tr(.mapPlaces), top: Theme.Map.firstGroupTop)
            AppList {
                ForEach(Array(places.enumerated()), id: \.element.id) { index, object in
                    row(object, first: index == 0)
                }
            }
            if !life.isEmpty {
                MapSheetParts.group(localization.tr(.mapLife), top: Theme.Map.groupTop)
                AppList {
                    ForEach(Array(life.enumerated()), id: \.element.id) { index, object in
                        AppListRow(
                            title: viewModel.objectName(object),
                            kind: .icon,
                            icon: Image("InfoUrban"),
                            showsTopDivider: index > 0
                        ) { viewModel.pickFromList(object.id) }
                        .accessibilityIdentifier("map.list.row.\(object.id)")
                    }
                }
            }
            MapSheetParts.close(viewModel)
                .padding(.top, Theme.Map.closeTop)
        }
    }

    private func row(_ object: MapContent.Object, first: Bool) -> some View {
        let localization = viewModel.localization
        let place = viewModel.place(object.place)
        let chapterID = object.chapter
        let lit = chapterID.map(viewModel.isOpen) ?? false
        let status: String? = chapterID.flatMap { id in
            viewModel.chapter(id).map { chapter in
                "\(localization.tr(.pathChapter, "\(viewModel.index(of: id))")) · "
                    + (lit ? localization.tr(.pathIsOpen) : localization.tr(.pathOpensAt, localization.format(Int(clamping: chapter.n))))
            }
        }
        return Button { viewModel.pickFromList(object.id) } label: {
            HStack(alignment: .top, spacing: Theme.Space.s3) {
                MapSheetParts.icon(lit ? "InfoStar" : SiraCategoryIcon.name(place?.cat ?? "city"), size: Theme.Size.iconList)
                    .frame(width: Theme.Size.iconColumn, alignment: .top)
                    .foregroundColor(Theme.Color.accent)
                    .padding(.top, Theme.Size.hairline)
                    .frame(minHeight: Theme.Size.iconListLineBox, alignment: .top)
                VStack(alignment: .leading, spacing: 0) {
                    Text(viewModel.text(place?.name))
                        .themeFont(.body)
                        .themeLineHeight(.body, multiple: Theme.Font.bodyLineHeightMultiple)
                        .foregroundColor(Theme.Color.text)
                        .multilineTextAlignment(.leading)
                    if let status {
                        Text(status)
                            .themeFont(.xs)
                            .themeLineHeight(.xs, multiple: Theme.Map.listSubLineMultiple)
                            .foregroundColor(Theme.Color.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Space.controlX)
            .padding(.vertical, Theme.Space.s3)
            .padding(.top, first ? 0 : Theme.Size.hairline)
            .frame(minHeight: Theme.Size.row)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Color.surface)
            .overlay(alignment: .top) {
                if !first { Theme.Color.divider.frame(height: Theme.Size.hairline) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("map.list.row.\(object.id)")
    }
}

/// openLegend(): примечание (.demo) и шесть строк условных обозначений.
struct MapLegendSheet: View {
    @ObservedObject var viewModel: MapViewModel

    var body: some View {
        let localization = viewModel.localization
        MapSheetContainer(viewModel: viewModel, identifier: "map.sheet.legend") {
            MapSheetParts.title(localization.tr(.mapLegend))
            Text(localization.tr(.mapDisclaimer))
                .themeFont(.calloutMedium)
                .themeLineHeight(.calloutMedium, multiple: Theme.Font.bodyLineHeightMultiple)
                .foregroundColor(Theme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, Theme.Map.demoPaddingY)
                .padding(.horizontal, Theme.Map.demoPaddingX)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Color.bgSubtle)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .padding(.top, Theme.Map.demoTop)
                .padding(.bottom, Theme.Map.demoBottom)
                .accessibilityIdentifier("map.legend.disclaimer")
            AppList {
                ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                    AppListRow(title: localization.tr(row.key), kind: .icon, icon: Image(row.icon), showsTopDivider: index > 0)
                }
            }
            .padding(.top, Theme.Map.legendListTop)
            MapSheetParts.close(viewModel)
                .padding(.top, Theme.Map.closeTop)
        }
    }

    private static let rows: [(icon: String, key: L10nKey)] = [
        ("TabInfo", .legendPlace), ("InfoStar", .legendLit), ("TabPath", .legendRoute),
        ("InfoUrban", .legendLife), ("InfoHand", .legendGesture), ("InfoList", .legendList),
    ]
}
