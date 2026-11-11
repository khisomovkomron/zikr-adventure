// MapView.swift
// ZKR-57: нативный экран «Карта» — renderMap() и renderCity() в index.html.
// Обзор: шапка (← «Зикр», «Карта», легенда, шестерёнка), SVG-карта, чип прогресса, кнопки городов
// с примечанием или панель выбранного города (cityPanel). Город: шапка (← обзор, название, список, легенда),
// сцена CityCanvas, чип «Главы Сиры в городе», «Предпросмотр», примечание, кнопки масштаба.
// Листы — SiraChapterSheet (место / глава) и MapSheets (объект, список мест, легенда). Логика — MapViewModel.

import SwiftUI
import ZikrContent
import ZikrDomain

struct MapView: View {
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var localization: LocalizationService

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var worldViewBox: [Double]
    @State private var assets: CitySceneAssets?
    @State private var scene: SceneSetup?

    /// Камера и проявление при создании сцены города (renderCity: city.cam, lastUnlockKey).
    private struct SceneSetup: Equatable {
        let cityID: String
        let camera: CityGeometry.Camera
        let animatesIntro: Bool
        let reveal: Set<String>
    }

    init(viewModel: MapViewModel) {
        self.viewModel = viewModel
        self.localization = viewModel.localization
        let geo = viewModel.selectedCity.flatMap { viewModel.mapContent?.geo.cities[$0] }
        _worldViewBox = State(initialValue: WorldGeometry.viewBox(city: geo))
        _assets = State(initialValue: viewModel.sceneCache)
    }

    private var reducesMotion: Bool { systemReduceMotion || !viewModel.animationsEnabled }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                switch viewModel.mode {
                case .world:
                    worldTopBar
                    worldMap
                case .city(let id):
                    cityTopBar(id)
                    cityMap(id)
                }
            }
            .background(Theme.Color.bg.ignoresSafeArea(edges: .top))
            .accessibilityHidden(viewModel.sheet != nil)

            if let sheet = viewModel.sheet {
                sheetView(sheet)
                    .id(sheet.id)
            }
        }
        .onChange(of: viewModel.selectedCity) { id in
            let target = WorldGeometry.viewBox(city: id.flatMap { viewModel.mapContent?.geo.cities[$0] })
            if reducesMotion || viewModel.mode != .world {
                worldViewBox = target
            } else {
                withAnimation(.timingCurve(0.455, 0.03, 0.515, 0.955, duration: Theme.Map.worldViewBoxDuration)) {
                    worldViewBox = target
                }
            }
        }
        .onDisappear { viewModel.didDisappear() }
        // .contain: иначе идентификатор экрана перекрывает идентификаторы шапки и кнопок.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.screen")
    }

    private func tr(_ key: L10nKey) -> String { localization.tr(key) }

    private func cityName(_ id: String) -> String {
        L10nKey(rawValue: "city.\(id)").map { tr($0) } ?? id
    }

    // MARK: - Шапки (.topbar)

    private var worldTopBar: some View {
        topBar(title: tr(.mapWorld), titleID: "map.world.title") {
            AppIconButton(image: Image("MapBack"), label: tr(.tabZikr)) { viewModel.selectTab(.zikr) }
                .accessibilityIdentifier("map.world.back")
        } trailing: {
            AppIconButton(image: Image("MapHelp"), label: tr(.mapLegend)) { viewModel.openLegend() }
                .accessibilityIdentifier("map.world.help")
            AppIconButton(image: Image("TabGear"), label: tr(.tabSettings)) { viewModel.selectTab(.settings) }
                .accessibilityIdentifier("map.world.settings")
        }
    }

    private func cityTopBar(_ id: String) -> some View {
        topBar(title: cityName(id), titleID: "map.city.title") {
            AppIconButton(image: Image("MapBack"), label: tr(.mapBack)) { viewModel.backToWorld() }
                .accessibilityIdentifier("map.city.back")
        } trailing: {
            AppIconButton(image: Image("InfoList"), label: tr(.mapList)) { viewModel.openList() }
                .accessibilityIdentifier("map.city.list")
            AppIconButton(image: Image("MapHelp"), label: tr(.mapLegend)) { viewModel.openLegend() }
                .accessibilityIdentifier("map.city.help")
        }
    }

    /// `.topbar`: space-between, gap 8, padding 10 16 6, min-height 52; h1 serif 20 / 600.
    private func topBar<Leading: View, Trailing: View>(
        title: String,
        titleID: String,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: Theme.Space.s2) {
            leading()
            Spacer(minLength: 0)
            Text(title)
                .themeFont(.headingMD)
                .tracking(Theme.Zikr.titleTracking)
                .foregroundColor(Theme.Color.text)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(titleID)
            Spacer(minLength: 0)
            HStack(spacing: Theme.Space.s2) { trailing() }
        }
        .padding(.top, Theme.Space.topbarTop)
        .padding(.bottom, Theme.Space.topbarBottom)
        .padding(.horizontal, Theme.Space.s4)
        .frame(maxWidth: .infinity, minHeight: Theme.Space.topbarMinHeight)
    }

    // MARK: - Обзорная карта

    @ViewBuilder
    private var worldMap: some View {
        if let geo = viewModel.mapContent?.geo {
            ZStack {
                Theme.Color.mapSea
                WorldMapCanvas(
                    viewBox: worldViewBox,
                    geo: geo,
                    selected: viewModel.selectedCity,
                    showsHijra: viewModel.isOpen("ch08"),
                    label: cityName,
                    onSelect: { viewModel.selectCity($0) },
                    onBackground: { if viewModel.selectedCity != nil { viewModel.selectCity(nil) } }
                )
                .accessibilityLabel(tr(.mapWorld))
                VStack(alignment: .leading, spacing: 0) {
                    chip(
                        icon: "TabPath",
                        text: localization.tr(
                            .mapProgress,
                            localization.format(Int(clamping: viewModel.total)),
                            localization.format(viewModel.unlocked.count),
                            localization.format(viewModel.chapterCount)
                        )
                    )
                    .accessibilityIdentifier("map.world.progress")
                    Spacer(minLength: Theme.Map.rowGap)
                    if let id = viewModel.selectedCity, let city = geo.cities[id] {
                        cityPanel(id, city)
                            .id(id)
                    } else {
                        cityButtons
                        disclaimer(maxWidthFraction: nil)
                    }
                }
                .padding(Theme.Map.overlayPadding)
            }
            .clipped()
        }
    }

    private var cityButtons: some View {
        HStack(spacing: Theme.Map.cityButtonsGap) {
            ForEach(MapContent.cityIDs, id: \.self) { id in
                AppButton(title: cityName(id), kind: .secondary) { viewModel.selectCity(id) }
                    .accessibilityIdentifier("map.world.pick.\(id)")
            }
        }
        .padding(.bottom, Theme.Map.cityButtonsBottom)
    }

    /// cityPanel(c): название, арабское название, крестик, описание, «Главы Сиры в городе», «Открыть карту города».
    private func cityPanel(_ id: String, _ city: MapContent.GeoCity) -> some View {
        let counts = viewModel.chapterCounts(city: id)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: Theme.Space.s2) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(cityName(id))
                        .themeFont(.headingLG, pointSize: Theme.Map.panelTitle)
                        .foregroundColor(Theme.Color.text)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("map.panel.title")
                    Text(city.ar)
                        .themeFont(.arabicName, scales: false)
                        .foregroundColor(Theme.Color.textSecondary)
                }
                Spacer(minLength: 0)
                Button { viewModel.selectCity(nil) } label: {
                    Image("ZikrClose")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Theme.Size.iconMd, height: Theme.Size.iconMd)
                        .foregroundColor(Theme.Color.text)
                        .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                        .background(Theme.Color.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr(.commonClose))
                .accessibilityIdentifier("map.panel.close")
            }
            Text(L10nKey(rawValue: "city.\(id).sum").map { tr($0) } ?? "")
                .themeFont(.callout)
                .themeLineHeight(.callout, multiple: Theme.Font.bodyLineHeightMultiple)
                .foregroundColor(Theme.Color.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, Theme.Map.panelSummaryY)
            Text(localization.tr(.mapChapters, localization.format(counts.open), localization.format(counts.total)))
                .themeFont(.xs)
                .foregroundColor(Theme.Color.textSecondary)
                .padding(.bottom, Theme.Map.panelCountBottom)
                .accessibilityIdentifier("map.panel.chapters")
            AppButton(title: tr(.mapOpen), kind: .primary, icon: Image("TabMap")) { viewModel.openCity(id) }
                .accessibilityIdentifier("map.panel.open")
        }
        .padding(.top, Theme.Map.panelTop)
        .padding(.horizontal, Theme.Map.panelX)
        .padding(.bottom, Theme.Map.panelBottom)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.Color.divider, lineWidth: Theme.Size.hairline)
        )
        .themeShadow(.card)
        .modifier(PanelRise(enabled: !reducesMotion))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.panel")
    }

    // MARK: - Карта города

    @ViewBuilder
    private func cityMap(_ id: String) -> some View {
        let groundKey = CitySceneAssets.groundKey(unlocked: viewModel.unlocked, preview: viewModel.preview)
        ZStack {
            Theme.Color.bgSubtle
            if let city = viewModel.city(id), let assets, assets.cityID == id, let scene, scene.cityID == id {
                CityCanvas(
                    city: city,
                    size: viewModel.mapContent?.size ?? 40,
                    assets: assets,
                    initialCamera: scene.camera,
                    animatesIntro: scene.animatesIntro && !reducesMotion,
                    reveal: scene.reveal,
                    open: viewModel.openChapters,
                    markers: markers(city),
                    selectedID: viewModel.selectedObjectID,
                    request: viewModel.cameraRequest,
                    reduceMotion: reducesMotion,
                    accessibilityLabel: tr(.mapA11y),
                    onTap: { viewModel.selectObject($0) },
                    onCameraSettle: { viewModel.cameraDidSettle(city: id, camera: $0) },
                    onRequestHandled: { viewModel.cameraRequestHandled($0) }
                )
                .id(id)
            }
            cityOverlay(id)
        }
        .clipped()
        .task(id: "\(id)|\(groundKey)") {
            await loadScene(id)
        }
    }

    private func loadScene(_ id: String) async {
        guard let city = viewModel.city(id) else { return }
        let key = CitySceneAssets.groundKey(unlocked: viewModel.unlocked, preview: viewModel.preview)
        let cached = assets.flatMap { $0.cityID == id && $0.groundKey == key ? $0 : nil }
        let built: CitySceneAssets?
        if let cached {
            built = cached
        } else {
            built = await CitySceneAssets.build(
                cityID: id,
                city: city,
                open: viewModel.openChapters,
                unlocked: viewModel.unlocked,
                preview: viewModel.preview,
                reusing: assets
            )
        }
        guard !Task.isCancelled, let built, viewModel.mode == .city(id) else { return }
        if scene?.cityID != id {
            let start = CityGeometry.initialCamera(saved: viewModel.savedCamera(id), city: city, size: viewModel.mapContent?.size ?? 40)
            scene = SceneSetup(
                cityID: id,
                camera: start.camera,
                animatesIntro: start.animatesIntro,
                reveal: viewModel.takeRevealedObjects(city: id, reduceMotion: reducesMotion)
            )
        }
        assets = built
        viewModel.sceneCache = built
    }

    private func markers(_ city: MapContent.City) -> [CityCanvasView.Marker] {
        city.objects.filter { $0.place != nil }.map {
            CityCanvasView.Marker(objectID: $0.id, lit: $0.chapter.map(viewModel.isOpen) ?? false, label: viewModel.label($0))
        }
    }

    private func cityOverlay(_ id: String) -> some View {
        let counts = viewModel.chapterCounts(city: id)
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Map.stackGap) {
                chip(icon: "InfoStar", text: localization.tr(.mapChapters, localization.format(counts.open), localization.format(counts.total)))
                    .accessibilityIdentifier("map.city.chapters")
                if viewModel.preview {
                    Text(tr(.previewBadge))
                        .font(.system(size: Theme.Map.badgeSize, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, Theme.Map.badgePaddingY)
                        .padding(.horizontal, Theme.Map.badgePaddingX)
                        .background(Capsule().fill(Theme.Color.warning))
                        .accessibilityIdentifier("map.city.preview")
                }
            }
            Spacer(minLength: Theme.Map.rowGap)
            HStack(alignment: .bottom, spacing: Theme.Map.rowGap) {
                disclaimer(maxWidthFraction: Theme.Map.disclaimerMaxWidth)
                Spacer(minLength: 0)
                VStack(spacing: Theme.Map.controlGap) {
                    control("MapPlus", tr(.mapZoomIn), "map.city.zoomIn") { viewModel.zoomIn() }
                    control("MapMinus", tr(.mapZoomOut), "map.city.zoomOut") { viewModel.zoomOut() }
                    control("MapScope", tr(.mapReset), "map.city.reset") { viewModel.resetCamera() }
                }
            }
        }
        .padding(Theme.Map.overlayPadding)
    }

    // MARK: - Элементы поверх карты

    /// `.mchip`.
    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: Theme.Map.chipGap) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Theme.Map.chipIcon, height: Theme.Map.chipIcon)
                .accessibilityHidden(true)
            Text(text)
                .themeFont(.kickerMedium)
                .lineLimit(2)
        }
        .foregroundColor(Theme.Color.text)
        .padding(.vertical, Theme.Map.chipPaddingY)
        .padding(.horizontal, Theme.Map.chipPaddingX)
        .background(Capsule().fill(Theme.Color.surface.opacity(Theme.Map.glassOpacity)).background(.ultraThinMaterial, in: Capsule()))
        .overlay(Capsule().strokeBorder(Theme.Color.divider, lineWidth: Theme.Size.hairline))
        .accessibilityElement(children: .combine)
    }

    /// `.disclaimer` (на обзоре — во всю ширину).
    private func disclaimer(maxWidthFraction: CGFloat?) -> some View {
        Text(tr(.mapDisclaimer))
            .font(.system(size: Theme.Map.disclaimerSize))
            .lineSpacing(Theme.Map.disclaimerSize * (Theme.Map.disclaimerLineHeight - 1.2))
            .foregroundColor(Theme.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, Theme.Map.disclaimerPaddingY)
            .padding(.horizontal, Theme.Map.disclaimerPaddingX)
            .background(
                RoundedRectangle(cornerRadius: Theme.Map.disclaimerRadius, style: .continuous)
                    .fill(Theme.Color.surface.opacity(Theme.Map.glassOpacity))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Map.disclaimerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Map.disclaimerRadius, style: .continuous)
                    .strokeBorder(Theme.Color.divider, lineWidth: Theme.Size.hairline)
            )
            .frame(maxWidth: maxWidthFraction.map { UIScreen.main.bounds.width * $0 } ?? .infinity, alignment: .leading)
            .accessibilityIdentifier("map.disclaimer")
    }

    /// `.ctrls .icon-btn`: 46, surface 90 % + blur, тень.
    private func control(_ icon: String, _ label: String, _ id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Theme.Size.iconMd, height: Theme.Size.iconMd)
                .foregroundColor(Theme.Color.text)
                .frame(width: Theme.Map.control, height: Theme.Map.control)
                .background(Circle().fill(Theme.Color.surface.opacity(Theme.Map.controlOpacity)).background(.ultraThinMaterial, in: Circle()))
                .overlay(Circle().strokeBorder(Theme.Color.divider, lineWidth: Theme.Size.hairline))
                .shadow(color: .black.opacity(Theme.Map.controlShadowOpacity), radius: Theme.Map.controlShadowRadius, x: 0, y: Theme.Map.controlShadowY)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    // MARK: - Листы

    @ViewBuilder
    private func sheetView(_ sheet: MapViewModel.Sheet) -> some View {
        switch sheet {
        case .chapter(let state):
            SiraChapterSheet(viewModel: viewModel, state: state)
        case .object(let id):
            if case .city(let cityID) = viewModel.mode, let object = viewModel.city(cityID)?.object(id: id) {
                MapObjectSheet(viewModel: viewModel, object: object)
            }
        case .list(let cityID):
            MapPlaceListSheet(viewModel: viewModel, cityID: cityID)
        case .legend:
            MapLegendSheet(viewModel: viewModel)
        }
    }
}

/// `.panel` animation: rise .28s ease (translateY 16, opacity 0).
private struct PanelRise: ViewModifier {
    let enabled: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .offset(y: shown || !enabled ? 0 : Theme.Map.panelRise)
            .opacity(shown || !enabled ? 1 : 0)
            .onAppear {
                guard enabled else { return }
                withAnimation(.timingCurve(0.25, 0.1, 0.25, 1, duration: Theme.Map.panelRiseDuration)) { shown = true }
            }
    }
}
