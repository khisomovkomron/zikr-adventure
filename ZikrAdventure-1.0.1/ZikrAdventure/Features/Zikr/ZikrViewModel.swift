// ZikrViewModel.swift
// ZKR-52: состояние нативного экрана «Зикр» (renderZikr() / refreshZikr() в index.html).
// Чтение — ProgressRepository (zikr-state.json, зеркало веба): load() и changes().
// Запись — только команды в веб (ZikrCommandSink → window.zikrNative.*): веб остаётся единственным писателем.
// Отклик оптимистичный: нажатие сразу меняет total / today / session, вибрация и звук — сразу.
// Затем ответ веба (снимок) и снимки zikr-state.json сверяют экран; пока в очереди есть
// неподтверждённые команды или снимок старше уже подтверждённого, значение на экране не откатывается.

import Foundation
import ZikrContent
import ZikrCore
import ZikrDomain

/// Баннер «Открыта новая глава Сиры» (showBanner(items)).
struct ZikrUnlockBanner: Equatable, Identifiable {
    /// Главы этой команды по порядку; в заголовке и «Изучить» — последняя (items[items.length - 1]).
    let chapterIDs: [String]
    let id: UUID

    var focusChapterID: String { chapterIDs[chapterIDs.count - 1] }
    var isSingle: Bool { chapterIDs.count == 1 }
}

@MainActor
final class ZikrViewModel: ObservableObject {
    /// Number.MAX_SAFE_INTEGER — верхняя граница total в onZikr().
    static let maxTotal: Int64 = 9_007_199_254_740_991

    /// nil — zikr-state.json ещё нет (зеркало не получило снимок): показывается веб-экран.
    @Published private(set) var settings: AppSettings?
    @Published private(set) var total: Int64 = 0
    @Published private(set) var today: Int64 = 0
    /// «За сеанс» — только в памяти, как `let session` в вебе: 0 при запуске и после сброса.
    @Published private(set) var session: Int64 = 0
    @Published private(set) var unlocked: [String] = []
    @Published private(set) var daily: [String: Int64] = [:]
    @Published private(set) var banner: ZikrUnlockBanner?
    /// Растёт на каждое нажатие — повод для ripple-анимации.
    @Published private(set) var tapCount = 0
    @Published var isResetDialogPresented = false
    @Published var isHistoryPresented = false
    @Published var isClearHistoryConfirmPresented = false

    let localization: LocalizationService
    let content: ZikrScreenContent?

    private let repository: any ProgressRepository
    private let sink: any ZikrCommandSink
    private let feedback: any ZikrFeedbackPerforming
    private let announcer: any AccessibilityAnnouncing
    private let clock: any AppClock
    private let bannerDuration: UInt64
    private let queue = SerialCommandQueue()
    /// state.updatedAt последнего подтверждённого вебом изменения: более старые снимки файла не применяются.
    private var confirmedUpdatedAt: Int64 = 0
    /// Команда не прошла — после очереди перечитать файл.
    private var needsResync = false
    private var bannerTask: Task<Void, Never>?
    private var isStarted = false

    init(
        repository: any ProgressRepository,
        sink: any ZikrCommandSink,
        contentProvider: any ZikrContentProviding,
        localization: LocalizationService,
        feedback: any ZikrFeedbackPerforming,
        announcer: any AccessibilityAnnouncing,
        clock: any AppClock = SystemClock(),
        bannerDuration: TimeInterval = Theme.Zikr.bannerAutoHide
    ) {
        self.repository = repository
        self.sink = sink
        self.localization = localization
        self.feedback = feedback
        self.announcer = announcer
        self.clock = clock
        self.bannerDuration = UInt64(max(0, bannerDuration) * 1_000_000_000)
        do {
            self.content = try contentProvider.loadZikrContent()
        } catch {
            Log.zikr.error("zikr-content.json not loaded")
            self.content = nil
        }
    }

    /// Без контента уровней/глав экран не показывается (остаётся веб, как в 1.1.1).
    var isAvailable: Bool { settings != nil && content != nil }
    var canUndoOrReset: Bool { total > 0 }
    var hasPendingCommands: Bool { queue.pending > 0 }

    var levelCard: ZikrProgress.LevelCard { ZikrProgress.levelCard(total: total) }
    var nextChapter: ZikrProgress.NextChapter? { ZikrProgress.nextChapter(total: total, unlocked: unlocked) }
    var openedCount: Int { ZikrProgress.openedCount(unlocked: unlocked) }
    var chapterCount: Int { content?.chapters.count ?? ChapterCatalog.thresholds.count }
    var goal: ZikrProgress.Goal? { settings.flatMap { ZikrProgress.goal(today: today, settings: $0) } }
    var historyDays: [(day: String, count: Int64)] { ZikrProgress.historyDays(daily: daily) }
    var animationsEnabled: Bool { settings?.animations ?? true }

    private var dayKey: String { DayKey.string(for: clock.now) }

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

    // MARK: - Действия (onZikr / onUndo / openResetDialog)

    func tap() {
        guard let settings else { return }
        total = min(total + 1, Self.maxTotal)
        today += 1
        session += 1
        daily[dayKey] = today
        tapCount &+= 1
        feedback.perform(.make(.tap(total: total), settings: settings))
        queue.enqueue { [weak self] in
            guard let self else { return }
            self.handle(await self.sink.tap())
        }
    }

    func undo() {
        guard let settings, total > 0 else { return }
        total -= 1
        if today > 0 { today -= 1 }
        daily[dayKey] = today
        session = max(0, session - 1)
        feedback.perform(.make(.undo, settings: settings))
        announcer.announce(localization.tr(.a11yCounter, localization.format(Int(total))))
        queue.enqueue { [weak self] in
            guard let self else { return }
            self.handle(await self.sink.undo())
        }
    }

    func requestReset() {
        guard total > 0 else { return }
        isResetDialogPresented = true
    }

    func reset(_ mode: ZikrResetMode) {
        isResetDialogPresented = false
        total = 0
        session = 0
        if mode == .all { unlocked = [] }
        announcer.announce(localization.tr(.a11yCounter, localization.format(0)))
        queue.enqueue { [weak self] in
            guard let self else { return }
            self.handle(await self.sink.reset(mode))
        }
    }

    // MARK: - История (openHistory)

    func openHistory() {
        isHistoryPresented = true
    }

    func closeHistory() {
        isHistoryPresented = false
        isClearHistoryConfirmPresented = false
    }

    func requestClearHistory() {
        isClearHistoryConfirmPresented = true
    }

    /// Как clearDailyHistory(): остаётся только сегодняшний день; лист закрывается.
    func confirmClearHistory() {
        let key = dayKey
        daily = daily[key].map { [key: $0] } ?? [:]
        closeHistory()
        queue.enqueue { [weak self] in
            guard let self else { return }
            if !(await self.sink.clearHistory()) { self.needsResync = true }
            await self.resyncIfIdle()
        }
    }

    // MARK: - Баннер (showBanner / hideBanner)

    func hideBanner() {
        bannerTask?.cancel()
        bannerTask = nil
        banner = nil
    }

    /// «Изучить»: глава на карте (или лист на «Пути Сиры»), веб сам переключает вкладку.
    func exploreBanner() {
        guard let id = banner?.focusChapterID else { return }
        hideBanner()
        queue.enqueue { [weak self] in
            guard let self else { return }
            await self.sink.explore(chapterID: id)
        }
    }

    func chapterTitle(_ id: String) -> String {
        content?.chapterTitle(id: id, language: localization.language.rawValue) ?? ""
    }

    func chapterYear(_ id: String) -> String {
        content?.chapterYear(id: id, language: localization.language.rawValue) ?? ""
    }

    func levelName(_ index: Int) -> String {
        content?.levelName(index: index, language: localization.language.rawValue) ?? ""
    }

    /// Ждёт выполнения всех поставленных команд (тесты).
    func drainCommands() async {
        await queue.drain()
    }

    // MARK: - Сверка

    private func handle(_ snapshot: ZikrSnapshot?) {
        let isLast = queue.pending <= 1
        guard let snapshot else {
            needsResync = true
            if isLast { Task { await resyncIfIdle() } }
            return
        }
        confirmedUpdatedAt = max(confirmedUpdatedAt, snapshot.updatedAt)
        if !snapshot.fresh.isEmpty {
            announceUnlock(snapshot.fresh)
        }
        if snapshot.unlocked != unlocked {
            unlocked = snapshot.unlocked
        }
        // Пока в очереди есть следующие нажатия, их оптимистичный счёт уже на экране.
        guard isLast else { return }
        if total != snapshot.total { total = snapshot.total }
        if snapshot.day == dayKey, today != snapshot.today {
            today = snapshot.today
            daily[snapshot.day] = snapshot.today
        }
        if needsResync { Task { await resyncIfIdle() } }
    }

    private func announceUnlock(_ fresh: [String]) {
        guard let settings else { return }
        feedback.perform(.make(.unlock, settings: settings))
        let message = fresh.count == 1
            ? localization.tr(.a11yUnlock, chapterTitle(fresh[0]))
            : localization.tr(.bannerMulti, localization.format(fresh.count))
        announcer.announce(message)
        guard settings.banners else { return }
        banner = ZikrUnlockBanner(chapterIDs: fresh, id: UUID())
        bannerTask?.cancel()
        let duration = bannerDuration
        bannerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled else { return }
            self?.banner = nil
        }
    }

    private func resyncIfIdle() async {
        guard queue.pending <= 1, needsResync else { return }
        needsResync = false
        confirmedUpdatedAt = 0
        if let loaded = await repository.load() {
            apply(loaded)
        }
    }

    /// Снимок zikr-state.json. Настройки применяются всегда; счёт — только если очередь пуста
    /// и снимок не старше подтверждённого ответа веба.
    private func apply(_ progress: ProgressState) {
        if settings != progress.settings {
            settings = progress.settings
        }
        guard queue.pending == 0, (progress.updatedAt ?? 0) >= confirmedUpdatedAt else { return }
        if total != progress.total { total = progress.total }
        if daily != progress.daily { daily = progress.daily }
        let todayValue = progress.daily[dayKey] ?? 0
        if today != todayValue { today = todayValue }
        if unlocked != progress.unlocked { unlocked = progress.unlocked }
        // resetAllProgress() из «Настроек» обнуляет и session в вебе.
        if progress.total == 0 { session = 0 }
    }
}
