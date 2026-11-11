// SiraViewModel.swift
// ZKR-53: состояние нативного экрана «Путь Сиры» (renderPath(), chapterCard(), placeCard() в index.html).
// Чтение — ProgressRepository (zikr-state.json, зеркало веба): total, unlocked, viewed, settings.
// Запись — только команды в веб (SiraCommandSink → window.zikrNative.*): веб остаётся единственным писателем.
// Метки «Новое» — как в вебе: renderPath() рисует их при показе вкладки (и при смене языка),
// поэтому «Читать» не снимает метку сразу — она исчезает при следующем показе вкладки.

import Foundation
import ZikrContent
import ZikrCore
import ZikrDomain

/// Открытый лист главы: chapterCard(ch, withMapBtn).
struct SiraChapterSheetState: Equatable, Identifiable {
    let chapterID: String
    /// «На карте» в листе: из строки «Читать» — да, из баннера «Изучить» (explore) — нет.
    let showsMapButton: Bool
    /// ZKR-57: placeCard(place, { siraFirst }) — блок Сиры первым (лист главы) или после «Облика» (место на карте).
    var siraFirst = true

    var id: String { chapterID }
}

@MainActor
final class SiraViewModel: ObservableObject, ChapterSheetModel {
    /// nil — zikr-state.json ещё нет (зеркало не получило снимок): показывается веб-экран.
    @Published private(set) var settings: AppSettings?
    @Published private(set) var total: Int64 = 0
    @Published private(set) var unlocked: [String] = []
    @Published private(set) var viewed: [String] = []
    /// viewed на момент показа вкладки — по нему рисуются метки «Новое» (как renderPath()).
    @Published private(set) var viewedAtEntry: Set<String> = []
    @Published private(set) var sheet: SiraChapterSheetState?

    let localization: LocalizationService
    let content: ZikrScreenContent?

    /// ZKR-57: «На карте» открывает нативную «Карту» (chapterID, с листом главы) → true; иначе — веб (showChapter / explore).
    /// Нативная карта сама отмечает просмотр (markViewed).
    var openOnMapNatively: ((String, Bool) -> Bool)?

    private let repository: any ProgressRepository
    private let sink: any SiraCommandSink
    private let queue = SerialCommandQueue()
    private var isStarted = false
    /// Вкладку открыл баннер «Изучить»: снимок «Новое» уже сделан до отметки просмотра.
    private var keepsEntrySnapshot = false
    private var snapshotLanguage: AppLanguage?

    init(
        repository: any ProgressRepository,
        sink: any SiraCommandSink,
        contentProvider: any ZikrContentProviding,
        localization: LocalizationService
    ) {
        self.repository = repository
        self.sink = sink
        self.localization = localization
        do {
            self.content = try contentProvider.loadZikrContent()
        } catch {
            Log.zikr.error("zikr-content.json not loaded (Sira)")
            self.content = nil
        }
    }

    /// Без контента глав экран не показывается (остаётся веб, как в 1.1.1).
    var isAvailable: Bool { settings != nil && content != nil && !(content?.places.isEmpty ?? true) }
    var preview: Bool { settings?.preview ?? false }
    var animationsEnabled: Bool { settings?.animations ?? true }
    private var language: String { localization.language.rawValue }

    var groups: [SiraJourney.Group] {
        SiraJourney.groups(total: total, chapters: content?.chapters.map { (id: $0.id, n: $0.n) } ?? ChapterCatalog.thresholds)
    }

    // MARK: - Подписка

    /// Чтение zikr-state.json. Работает, пока жив вызывающий Task (TabsView.task).
    func start() async {
        guard !isStarted else { return }
        isStarted = true
        defer { isStarted = false }
        // Сначала подписка, потом load(): запись между ними не теряется.
        let stream = await repository.changes()
        if let loaded = await repository.load() {
            apply(loaded)
        }
        for await next in stream {
            apply(next)
        }
    }

    // MARK: - Показ вкладки (renderPath)

    /// Вкладка показана: снимок просмотренных глав для меток «Новое».
    func didAppear() {
        if keepsEntrySnapshot {
            keepsEntrySnapshot = false
            return
        }
        takeEntrySnapshot()
    }

    /// Вкладка скрыта: лист закрывается (как лист «Инфо» и «История»).
    func didDisappear() {
        sheet = nil
    }

    // MARK: - Строки (renderPath row)

    func chapter(_ id: String) -> ZikrScreenContent.Chapter? { content?.chapter(id: id) }
    func index(of id: String) -> Int { content?.chapterIndex(id: id) ?? 0 }
    func isOpen(_ id: String) -> Bool { SiraJourney.isOpen(id, unlocked: unlocked, preview: preview) }
    func isNew(_ id: String) -> Bool { SiraJourney.isNew(id, unlocked: unlocked, viewed: viewedAtEntry) }
    func title(_ id: String) -> String { content?.chapterTitle(id: id, language: language) ?? "" }
    func year(_ id: String) -> String { content?.chapterYear(id: id, language: language) ?? "" }
    func levelName(_ index: Int) -> String { content?.levelName(index: index, language: language) ?? "" }
    func text(_ values: [String: String]?) -> String { values.map { ZikrScreenContent.pick($0, language: language) } ?? "" }
    func place(_ id: String?) -> ZikrScreenContent.Place? { id.flatMap { content?.places[$0] } }

    // MARK: - Действия

    /// «Читать» (data-read): лист главы; chapterCard / placeCard отмечают просмотр.
    func read(_ id: String) {
        guard chapter(id) != nil, isOpen(id) else { return }
        sheet = SiraChapterSheetState(chapterID: id, showsMapButton: true)
        markViewed(id)
    }

    /// «На карте» в строке (data-go): markViewed + openCity — веб переключит вкладку на «Карту».
    func showOnMap(_ id: String) {
        guard chapter(id)?.city != nil, isOpen(id) else { return }
        noteViewed(id)
        if openOnMapNatively?(id, false) == true { return }
        queue.enqueue { [weak self] in
            guard let self else { return }
            await self.sink.showChapter(chapterID: id)
        }
    }

    /// «На карте» в листе (#card-map): closeSheet(true); explore(ch) — карта города и лист главы на ней.
    func exploreFromSheet() {
        guard let id = sheet?.chapterID else { return }
        sheet = nil
        if chapter(id)?.city != nil, openOnMapNatively?(id, true) == true { return }
        queue.enqueue { [weak self] in
            guard let self else { return }
            await self.sink.explore(chapterID: id)
        }
    }

    func closeSheet() {
        sheet = nil
    }

    /// ZKR-52 → ZKR-53: «Изучить» в баннере «Зикра» для главы без города — explore(ch) в вебе:
    /// selectTab("path") (метки «Новое» рисуются до отметки), затем лист chapterCard(ch, false).
    /// false — глава неизвестна или у неё есть город (тогда карта, как раньше).
    func openFromBanner(_ id: String) -> Bool {
        guard let chapter = chapter(id), chapter.city == nil else { return false }
        takeEntrySnapshot()
        keepsEntrySnapshot = true
        sheet = SiraChapterSheetState(chapterID: id, showsMapButton: false)
        markViewed(id)
        return true
    }

    /// Ждёт выполнения всех поставленных команд (тесты).
    func drainCommands() async {
        await queue.drain()
    }

    // MARK: - Расстояние (distText)

    /// `distText(placeId)`: «От Каабы: ~4,8 км, северо-восток» / «центр карты» / «Сафа: ~130 м, юго-восток · Марва: …».
    func distanceText(_ place: ZikrScreenContent.Place) -> String {
        Self.distanceText(place, content: content, localization: localization)
    }

    /// ZKR-57: общий для листов «Пути Сиры» и «Карты».
    static func distanceText(_ place: ZikrScreenContent.Place, content: ZikrScreenContent?, localization: LocalizationService) -> String {
        let language = localization.language.rawValue
        let base = localization.tr(place.city == "mecca" ? .distKaaba : .distNabawi)
        let parts = place.dist.map { leg -> String in
            guard leg.m != 0 else { return localization.tr(.cardCenter) }
            let value = leg.m >= 1_000
                ? "~\(localization.format(Double(leg.m) / 1_000, maximumFractionDigits: 1)) \(localization.tr(.unitKm))"
                : "~\(localization.format(Int(leg.m))) \(localization.tr(.unitM))"
            let prefix = leg.sub.map { "\(content?.safaMarwaLabel($0, language: language) ?? ""): " } ?? ""
            let direction = leg.dir.flatMap { L10nKey(rawValue: "dir.\($0)") }.map { localization.tr($0) } ?? ""
            return "\(prefix)\(value), \(direction)"
        }
        return "\(base): \(parts.joined(separator: " · "))"
    }

    // MARK: - Запись

    private func markViewed(_ id: String) {
        noteViewed(id)
        queue.enqueue { [weak self] in
            guard let self else { return }
            await self.sink.markViewed(chapterID: id)
        }
    }

    /// Оптимистично: веб добавит главу в viewed и пришлёт снимок; меткам «Новое» это не мешает.
    private func noteViewed(_ id: String) {
        if !viewed.contains(id) { viewed.append(id) }
    }

    private func takeEntrySnapshot() {
        viewedAtEntry = Set(viewed)
        snapshotLanguage = settings?.lang
    }

    private func apply(_ progress: ProgressState) {
        if settings != progress.settings {
            settings = progress.settings
        }
        if total != progress.total { total = progress.total }
        if unlocked != progress.unlocked { unlocked = progress.unlocked }
        // Пока команды в очереди, снимок без них не откатывает оптимистичный viewed.
        let merged = queue.pending > 0 ? progress.viewed + viewed.filter { !progress.viewed.contains($0) } : progress.viewed
        if viewed != merged { viewed = merged }
        // renderAll() при смене языка перерисовывает вкладку: метки «Новое» — по текущему viewed.
        if let snapshotLanguage, snapshotLanguage != progress.settings.lang {
            takeEntrySnapshot()
        }
        if let id = sheet?.chapterID, chapter(id) != nil, !isOpen(id) {
            sheet = nil
        }
    }
}
