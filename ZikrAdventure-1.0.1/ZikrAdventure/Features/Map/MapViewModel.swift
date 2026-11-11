// MapViewModel.swift
// ZKR-57: состояние нативного экрана «Карта» — renderMap() (обзорная карта, панель города), renderCity()
// (сцена города, листы placeCard / objectCard / openPlaceList / openLegend) и explore() в index.html.
// Чтение — ProgressRepository (zikr-state.json, зеркало веба): total, unlocked, viewed, settings, cameras, city.
// Запись — только команды в веб (MapCommandSink → window.zikrNative.*): веб остаётся единственным писателем.
// Сцену города (камера, жесты, отрисовка) ведёт CityCanvasView; модель хранит запросы камеры и выбор объекта.

import Foundation
import ZikrContent
import ZikrCore
import ZikrDomain

@MainActor
final class MapViewModel: ObservableObject, ChapterSheetModel {
    enum Mode: Equatable {
        case world
        case city(String)
    }

    /// Лист поверх карты (openSheet): глава / место, объект городской среды, список мест, легенда.
    enum Sheet: Equatable, Identifiable {
        case chapter(SiraChapterSheetState)
        case object(String)
        case list(String)
        case legend

        var id: String {
            switch self {
            case .chapter(let state): return "chapter.\(state.chapterID).\(state.siraFirst)"
            case .object(let id): return "object.\(id)"
            case .list(let city): return "list.\(city)"
            case .legend: return "legend"
            }
        }
    }

    /// Команда камере сцены (animateCam / focusObject); id растёт, чтобы повтор той же команды сработал.
    struct CameraRequest: Equatable {
        enum Kind: Equatable {
            case zoom(Double)
            case home
            case focus(String)
        }

        let id: Int
        let kind: Kind
    }

    @Published private(set) var settings: AppSettings?
    @Published private(set) var total: Int64 = 0
    @Published private(set) var unlocked: [String] = []
    @Published private(set) var mode: Mode = .world
    /// mapView.selected: выбранный город обзорной карты (state.city).
    @Published private(set) var selectedCity: String?
    @Published private(set) var sheet: Sheet?
    /// city.selected: подсвеченный объект сцены (пульсирующий ромб).
    @Published private(set) var selectedObjectID: String?
    @Published private(set) var cameraRequest: CameraRequest?

    let localization: LocalizationService
    let content: ZikrScreenContent?
    let mapContent: MapContent?
    /// Растры последнего показанного города: при возврате на вкладку сцена не собирается заново.
    var sceneCache: CitySceneAssets?
    /// Переход на другую вкладку (кнопки «Назад» → «Зикр» и шестерёнка → «Настройки» на обзорной карте).
    var onSelectTab: ((TabItem) -> Void)?

    private let repository: any ProgressRepository
    private let sink: any MapCommandSink
    private let queue = SerialCommandQueue()
    private var isStarted = false
    private var hasState = false
    /// state.cameras: снимок веба + камеры, сохранённые здесь (снимок с ними приходит позже).
    private var cameras: [String: CameraPosition] = [:]
    /// lastUnlockKey: набор открытых глав при прошлом показе города — для проявления новых объектов.
    private var lastUnlockKey: [String: String] = [:]
    private var requestCounter = 0
    private var pendingSheet: Task<Void, Never>?
    private var viewedLocally: [String] = []
    private var viewed: [String] = []

    init(
        repository: any ProgressRepository,
        sink: any MapCommandSink,
        mapContentProvider: any MapContentProviding,
        contentProvider: any ZikrContentProviding,
        localization: LocalizationService
    ) {
        self.repository = repository
        self.sink = sink
        self.localization = localization
        do {
            self.mapContent = try mapContentProvider.loadMapContent()
        } catch {
            Log.zikr.error("map-content.json not loaded")
            self.mapContent = nil
        }
        do {
            self.content = try contentProvider.loadZikrContent()
        } catch {
            Log.zikr.error("zikr-content.json not loaded (Map)")
            self.content = nil
        }
    }

    /// Без контента карт и глав экран не показывается (остаётся веб, как в 1.1.1).
    var isAvailable: Bool { settings != nil && mapContent != nil && content != nil && !(content?.places.isEmpty ?? true) }
    var preview: Bool { settings?.preview ?? false }
    var animationsEnabled: Bool { settings?.animations ?? true }
    private var language: String { localization.language.rawValue }

    // MARK: - Подписка

    func start() async {
        guard !isStarted else { return }
        isStarted = true
        defer { isStarted = false }
        let stream = await repository.changes()
        if let loaded = await repository.load() {
            apply(loaded)
        }
        for await next in stream {
            apply(next)
        }
    }

    /// Вкладка скрыта: лист закрывается (как листы других экранов).
    func didDisappear() {
        pendingSheet?.cancel()
        pendingSheet = nil
        closeSheet()
    }

    // MARK: - Главы и места (ChapterSheetModel)

    func chapter(_ id: String) -> ZikrScreenContent.Chapter? { content?.chapter(id: id) }
    func index(of id: String) -> Int { content?.chapterIndex(id: id) ?? 0 }
    func isOpen(_ id: String) -> Bool { SiraJourney.isOpen(id, unlocked: unlocked, preview: preview) }
    func title(_ id: String) -> String { content?.chapterTitle(id: id, language: language) ?? "" }
    func year(_ id: String) -> String { content?.chapterYear(id: id, language: language) ?? "" }
    func text(_ values: [String: String]?) -> String { values.map { ZikrScreenContent.pick($0, language: language) } ?? "" }
    func place(_ id: String?) -> ZikrScreenContent.Place? { id.flatMap { content?.places[$0] } }
    func distanceText(_ place: ZikrScreenContent.Place) -> String {
        SiraViewModel.distanceText(place, content: content, localization: localization)
    }

    /// На карте у листа нет «На карте» (chapterCard(ch, false) / placeCard(place)).
    func exploreFromSheet() {}

    /// Открытые главы (isOpen) — видимость объектов и наложений сцены.
    var openChapters: [String] {
        content?.chapters.map(\.id).filter { isOpen($0) } ?? unlocked
    }

    /// «Главы Сиры в городе: %1 из %2» — по реально открытым (isReallyOpen), без предпросмотра.
    func chapterCounts(city: String) -> (open: Int, total: Int) {
        let chapters = content?.chapters.filter { $0.city == city } ?? []
        return (chapters.filter { SiraJourney.isReallyOpen($0.id, unlocked: unlocked) }.count, chapters.count)
    }

    var chapterCount: Int { content?.chapters.count ?? 0 }

    func city(_ id: String) -> MapContent.City? { mapContent?.cities[id] }

    func savedCamera(_ cityID: String) -> CityGeometry.Camera? {
        cameras[cityID].map { CityGeometry.Camera(x: $0.x, y: $0.y, z: $0.z) }
    }

    /// Название места для метки и списка: подпись Сафа / Марва или имя без «(…)» в конце.
    func label(_ object: MapContent.Object) -> String {
        if let sub = object.sub, object.place == "safamarwa" {
            return content?.safaMarwaLabel(sub, language: language) ?? ""
        }
        let name = text(place(object.place)?.name)
        return name.replacingOccurrences(of: #" ?\(.+\)$"#, with: "", options: .regularExpression)
    }

    /// T(o.name): ключ obj.* (как в вебе: нет ключа — показывается сам ключ).
    func objectName(_ object: MapContent.Object) -> String {
        guard let key = object.name else { return "" }
        return L10nKey(rawValue: key).map { localization.tr($0) } ?? key
    }

    // MARK: - Обзорная карта

    /// selectWorldCity(c): маркер, кнопка города, крестик панели (nil), нажатие на фон (nil).
    func selectCity(_ id: String?) {
        guard id == nil || mapContent?.geo.cities[id ?? ""] != nil else { return }
        selectedCity = id
        enqueue { await $0.sink.selectCity(id) }
    }

    /// «Открыть карту города» / openCity(id, focusId).
    func openCity(_ id: String, focus: String? = nil) {
        guard let city = city(id) else { return }
        mode = .city(id)
        if selectedCity != id {
            selectedCity = id
        }
        enqueue { await $0.sink.selectCity(id) }
        selectedObjectID = nil
        cameraRequest = nil
        if let focus, city.object(id: focus) != nil {
            selectedObjectID = focus
            request(.focus(focus))
        }
    }

    /// Кнопка «Назад» сцены города: обзорная карта (выбранный город остаётся).
    func backToWorld() {
        pendingSheet?.cancel()
        sheet = nil
        selectedObjectID = nil
        cameraRequest = nil
        mode = .world
    }

    /// Сцена выполнила запрос камеры: при пересоздании сцены (возврат на вкладку) он не повторяется.
    func cameraRequestHandled(_ id: Int) {
        if cameraRequest?.id == id { cameraRequest = nil }
    }

    func selectTab(_ tab: TabItem) {
        onSelectTab?(tab)
    }

    // MARK: - Переходы из «Пути Сиры» и «Зикра»

    /// explore(ch): отметка просмотра, карта города с фокусом на месте главы, через 550 мс (50 — без анимаций)
    /// лист chapterCard(ch, false). false — у главы нет города (лист показывает «Путь Сиры»).
    @discardableResult
    func explore(_ chapterID: String) -> Bool {
        guard let chapter = chapter(chapterID), let cityID = chapter.city, city(cityID) != nil else { return false }
        markViewed(chapterID)
        openCity(cityID, focus: Self.chapterFocus(chapter))
        pendingSheet?.cancel()
        let delay: UInt64 = animationsEnabled ? 550_000_000 : 50_000_000
        pendingSheet = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self, !Task.isCancelled else { return }
            self.sheet = .chapter(SiraChapterSheetState(chapterID: chapterID, showsMapButton: false))
        }
        return true
    }

    /// «На карте» в строке главы (data-go): markViewed + openCity без листа.
    @discardableResult
    func showChapter(_ chapterID: String) -> Bool {
        guard let chapter = chapter(chapterID), let cityID = chapter.city, city(cityID) != nil else { return false }
        markViewed(chapterID)
        openCity(cityID, focus: Self.chapterFocus(chapter))
        return true
    }

    /// chapterFocus(ch): объект сцены для места главы.
    static func chapterFocus(_ chapter: ZikrScreenContent.Chapter) -> String? {
        switch chapter.place {
        case "safamarwa": return "safa"
        case "hira": return "nur"
        case let place?: return place
        case nil: return chapter.focus
        }
    }

    // MARK: - Сцена города

    /// selectObject(city, o): нажатие на объект (hitTest) — место → placeCard, иначе objectCard.
    func selectObject(_ objectID: String?) {
        guard case .city(let cityID) = mode else { return }
        guard let objectID, let object = city(cityID)?.object(id: objectID) else {
            selectedObjectID = nil
            return
        }
        selectedObjectID = objectID
        if object.place != nil, let chapterID = object.chapter {
            // placeCard(): открытая глава отмечается просмотренной.
            if isOpen(chapterID) { markViewed(chapterID) }
            sheet = .chapter(SiraChapterSheetState(chapterID: chapterID, showsMapButton: false, siraFirst: false))
        } else {
            sheet = .object(objectID)
        }
    }

    func zoomIn() { request(.zoom(1.4)) }
    func zoomOut() { request(.zoom(1 / 1.4)) }
    func resetCamera() { request(.home) }

    func openList() {
        guard case .city(let id) = mode else { return }
        sheet = .list(id)
    }

    func openLegend() {
        sheet = .legend
    }

    /// Строка списка: closeSheet(true) (без снятия выбора), focusObject, через 380 мс (0) — selectObject.
    func pickFromList(_ objectID: String) {
        sheet = nil
        request(.focus(objectID))
        pendingSheet?.cancel()
        let delay: UInt64 = animationsEnabled ? 380_000_000 : 0
        pendingSheet = Task { @MainActor [weak self] in
            if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            guard let self, !Task.isCancelled else { return }
            self.selectObject(objectID)
        }
    }

    /// closeSheet(): «Закрыть», затемнение, Escape. Колбэк листов места/объекта/главы снимает выбор.
    func closeSheet() {
        sheet = nil
        selectedObjectID = nil
    }

    /// Места списка: места города (без Марвы, sub 1) и до 12 видимых объектов среды со слоем главы.
    func listPlaces(city cityID: String) -> [MapContent.Object] {
        city(cityID)?.objects.filter { $0.place != nil && $0.sub != 1 } ?? []
    }

    func listLife(city cityID: String) -> [MapContent.Object] {
        let open = Set(openChapters)
        let life = city(cityID)?.objects.filter {
            $0.place == nil && $0.isInteractive && $0.layer != nil && CityGeometry.isVisible($0, isOpen: open.contains)
        } ?? []
        return Array(life.prefix(12))
    }

    /// Камера после жеста или анимации (saveCam).
    func cameraDidSettle(city cityID: String, camera: CityGeometry.Camera) {
        let position = CameraPosition(x: camera.x, y: camera.y, z: camera.z)
        guard cameras[cityID] != position else { return }
        cameras[cityID] = position
        enqueue { await $0.sink.saveCamera(cityID: cityID, x: camera.x, y: camera.y, z: camera.z) }
    }

    /// Объекты, проявляющиеся при показе города (слой открылся с прошлого показа). Обновляет lastUnlockKey.
    func takeRevealedObjects(city cityID: String, reduceMotion: Bool) -> Set<String> {
        let key = CityGeometry.unlockKey(unlocked)
        defer { lastUnlockKey[cityID] = key }
        guard let previous = lastUnlockKey[cityID], previous != key, !reduceMotion, let city = city(cityID) else { return [] }
        let before = Set(previous.split(separator: "|").map(String.init))
        return Set(city.objects.filter { o in o.layer.map { !before.contains($0) && isOpen($0) } ?? false }.map(\.id))
    }

    /// Ждёт выполнения всех поставленных команд (тесты).
    func drainCommands() async {
        await queue.drain()
    }

    // MARK: - Запись

    private func markViewed(_ id: String) {
        enqueue { await $0.sink.markViewed(chapterID: id) }
    }

    private func request(_ kind: CameraRequest.Kind) {
        requestCounter += 1
        cameraRequest = CameraRequest(id: requestCounter, kind: kind)
    }

    private func enqueue(_ work: @escaping @MainActor (MapViewModel) async -> Void) {
        queue.enqueue { [weak self] in
            guard let self else { return }
            await work(self)
        }
    }

    private func apply(_ progress: ProgressState) {
        if settings != progress.settings { settings = progress.settings }
        if total != progress.total { total = progress.total }
        if unlocked != progress.unlocked { unlocked = progress.unlocked }
        // Пока команды в очереди, снимок без них не откатывает локальные камеры и выбор города.
        if queue.pending == 0 {
            cameras = progress.cameras
            if !hasState, case .world = mode { selectedCity = progress.city }
        } else {
            cameras = progress.cameras.merging(cameras) { _, local in local }
        }
        if !hasState {
            hasState = true
            if queue.pending > 0, case .world = mode, selectedCity == nil { selectedCity = progress.city }
        }
    }
}
