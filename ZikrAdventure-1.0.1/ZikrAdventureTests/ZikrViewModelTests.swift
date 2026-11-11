// ZikrViewModelTests.swift
// ZKR-52: экран «Зикр» — оптимистичный счёт, сверка с вебом и zikr-state.json, «Исправить», сброс,
// история, session, личная цель, баннер открытия главы, вибрация/звук и VoiceOver.

import UIKit
import XCTest
import ZikrContent
import ZikrCore
import ZikrDomain
@testable import ZikrAdventure

@MainActor
final class ZikrViewModelTests: XCTestCase {
    /// 11.11.2026 12:00 в часовом поясе устройства.
    private let now: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = 11; c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c)!
    }()
    private var day: String { DayKey.string(for: now) }

    private var repository: FakeProgressRepository!
    private var sink: FakeZikrSink!
    private var feedback: FakeZikrFeedback!
    private var announcer: FakeAnnouncer!
    private var localization: LocalizationService!
    private var viewModel: ZikrViewModel!
    private var startTask: Task<Void, Never>?

    private func makeState(total: Int64 = 0, today: Int64 = 0, unlocked: [String] = [], settings: AppSettings = AppSettings(lang: .en)) -> ProgressState {
        var state = ProgressState(total: total, unlocked: unlocked, settings: settings, onboarded: true, updatedAt: 100)
        if today > 0 { state.daily[day] = today }
        return state
    }

    private func setUp(_ state: ProgressState?, bannerDuration: TimeInterval = 7) async {
        repository = FakeProgressRepository(state)
        sink = FakeZikrSink(state: state ?? ProgressState(), day: day)
        feedback = FakeZikrFeedback()
        announcer = FakeAnnouncer()
        localization = LocalizationService(language: .en, defaults: nil)
        viewModel = ZikrViewModel(
            repository: repository,
            sink: sink,
            contentProvider: StaticZikrContentProvider(testZikrContent()),
            localization: localization,
            feedback: feedback,
            announcer: announcer,
            clock: FixedClock(now),
            bannerDuration: bannerDuration
        )
        let viewModel = self.viewModel!
        startTask = Task { await viewModel.start() }
        if state != nil {
            await waitUntil { viewModel.isAvailable }
        }
    }

    override func tearDown() async throws {
        startTask?.cancel()
        startTask = nil
    }

    // MARK: - Загрузка

    func testNoStateFileKeepsWebScreen() async {
        await setUp(nil)
        await waitUntil { await self.repository.subscriberCount == 1 }
        XCTAssertFalse(viewModel.isAvailable)
        viewModel.tap()
        XCTAssertEqual(viewModel.total, 0, "без данных нажатия не принимаются")
        XCTAssertTrue(sink.calls.isEmpty)
    }

    func testMissingContentKeepsWebScreen() async {
        repository = FakeProgressRepository(makeState())
        viewModel = ZikrViewModel(
            repository: repository, sink: FakeZikrSink(state: makeState(), day: day),
            contentProvider: FailingZikrContentProvider(), localization: LocalizationService(language: .en, defaults: nil),
            feedback: FakeZikrFeedback(), announcer: FakeAnnouncer(), clock: FixedClock(now)
        )
        let viewModel = self.viewModel!
        startTask = Task { await viewModel.start() }
        await waitUntil { viewModel.settings != nil }
        XCTAssertFalse(viewModel.isAvailable)
    }

    func testLoadsTotalTodayAndUnlocked() async {
        var state = makeState(total: 1_234, today: 56, unlocked: ["ch01", "ch02"])
        state.daily["2026-11-10"] = 7
        await setUp(state)
        XCTAssertEqual(viewModel.total, 1_234)
        XCTAssertEqual(viewModel.today, 56)
        XCTAssertEqual(viewModel.session, 0)
        XCTAssertEqual(viewModel.unlocked, ["ch01", "ch02"])
        XCTAssertEqual(viewModel.openedCount, 2)
        XCTAssertEqual(viewModel.chapterCount, 19)
        XCTAssertEqual(viewModel.levelCard.number, 3)
        XCTAssertEqual(viewModel.nextChapter?.id, "ch03")
        XCTAssertTrue(viewModel.canUndoOrReset)
    }

    func testZeroDisablesUndoAndReset() async {
        await setUp(makeState())
        XCTAssertFalse(viewModel.canUndoOrReset)
        viewModel.undo()
        viewModel.requestReset()
        XCTAssertEqual(viewModel.total, 0, "нельзя уйти ниже 0")
        XCTAssertFalse(viewModel.isResetDialogPresented)
        await viewModel.drainCommands()
        XCTAssertTrue(sink.calls.isEmpty)
    }

    // MARK: - Нажатие

    func testTapIsOptimisticAndSendsCommand() async {
        await setUp(makeState(total: 5, today: 2))
        viewModel.tap()
        // Сразу, до ответа веба.
        XCTAssertEqual(viewModel.total, 6)
        XCTAssertEqual(viewModel.today, 3)
        XCTAssertEqual(viewModel.session, 1)
        XCTAssertEqual(viewModel.tapCount, 1)
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls, [.tap])
        XCTAssertEqual(viewModel.total, 6)
        XCTAssertEqual(viewModel.today, 3)
    }

    func test33TapsMatchesWebCounters() async {
        await setUp(makeState())
        for _ in 0..<33 { viewModel.tap() }
        await viewModel.drainCommands()
        XCTAssertEqual(viewModel.total, 33)
        XCTAssertEqual(viewModel.today, 33)
        XCTAssertEqual(viewModel.session, 33)
        XCTAssertEqual(sink.state.total, 33)
        XCTAssertEqual(sink.state.daily[day], 33)
    }

    /// Риск из плана (раздел 2.2): 200 быстрых нажатий — без потерь и перестановок,
    /// экран не откатывается, пока команды в очереди.
    func test200RapidTapsAreSerialAndLossless() async {
        await setUp(makeState())
        sink.delayNanoseconds = 1_000_000
        for _ in 0..<200 { viewModel.tap() }
        XCTAssertEqual(viewModel.total, 200, "оптимистично сразу")
        // Устаревший снимок файла посреди очереди не откатывает экран.
        var stale = makeState(total: 3, today: 3)
        stale.updatedAt = 101
        await repository.emit(stale)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(viewModel.total, 200)
        await viewModel.drainCommands()
        XCTAssertEqual(sink.appliedTotals, Array(1...200), "веб выполнил нажатия по порядку")
        XCTAssertEqual(viewModel.total, 200)
        XCTAssertEqual(viewModel.today, 200)
        XCTAssertEqual(viewModel.session, 200)
        XCTAssertFalse(viewModel.hasPendingCommands)
        // Снимок файла старше подтверждённого ответа веба тоже не применяется.
        var older = makeState(total: 150, today: 150)
        older.updatedAt = 120
        await repository.emit(older)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(viewModel.total, 200)
        // А актуальный снимок (то же updatedAt, что у веба) — применяется.
        var current = sink.state
        current.settings = AppSettings(lang: .en)
        await repository.emit(current)
        await waitUntil { self.viewModel.total == 200 && self.viewModel.daily[self.day] == 200 }
    }

    func testWebIsSourceOfTruthAfterQueue() async {
        await setUp(makeState(total: 10))
        // Веб уже насчитал больше (например, нажатия веб-экрана).
        sink.state.total = 50
        viewModel.tap()
        XCTAssertEqual(viewModel.total, 11)
        await viewModel.drainCommands()
        XCTAssertEqual(viewModel.total, 51, "ответ веба побеждает оптимистичное значение")
    }

    func testFailedCommandResyncsFromFile() async {
        await setUp(makeState(total: 10, today: 4))
        sink.fails = true
        viewModel.tap()
        XCTAssertEqual(viewModel.total, 11)
        await viewModel.drainCommands()
        await waitUntil { self.viewModel.total == 10 }
        XCTAssertEqual(viewModel.today, 4)
    }

    func testExternalChangeAppliesWhenIdle() async {
        await setUp(makeState(total: 10, today: 4))
        var next = makeState(total: 0, today: 4)
        next.updatedAt = 500
        viewModel.tap()
        await viewModel.drainCommands()
        XCTAssertEqual(viewModel.session, 1)
        // «Сбросить прогресс» в Настройках: веб пишет total 0 → и session 0, как resetAllProgress().
        await repository.emit(next)
        await waitUntil { self.viewModel.total == 0 }
        XCTAssertEqual(viewModel.session, 0)
    }

    func testSettingsChangeAppliesEvenWithPendingCommands() async {
        await setUp(makeState(total: 1))
        sink.delayNanoseconds = 50_000_000
        viewModel.tap()
        var next = makeState(total: 1, settings: AppSettings(translit: false, lang: .en))
        next.updatedAt = 1
        await repository.emit(next)
        await waitUntil { self.viewModel.settings?.translit == false }
        XCTAssertEqual(viewModel.total, 2, "счёт не откатился")
    }

    // MARK: - Исправить / Обнулить

    func testUndo() async {
        await setUp(makeState(total: 33, today: 1, unlocked: ["ch01", "ch02"]))
        viewModel.tap()
        viewModel.undo()
        viewModel.undo()
        XCTAssertEqual(viewModel.total, 32)
        XCTAssertEqual(viewModel.today, 0)
        XCTAssertEqual(viewModel.session, 0, "session не уходит ниже 0")
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls, [.tap, .undo, .undo])
        XCTAssertEqual(viewModel.total, 32)
        XCTAssertEqual(viewModel.today, 0)
        XCTAssertEqual(announcer.messages, ["Counter: 33", "Counter: 32"])
    }

    func testResetCounterKeepsChapters() async {
        await setUp(makeState(total: 120, today: 20, unlocked: ["ch01", "ch02", "ch03", "ch04"]))
        viewModel.tap()
        viewModel.requestReset()
        XCTAssertTrue(viewModel.isResetDialogPresented)
        viewModel.reset(.counter)
        XCTAssertFalse(viewModel.isResetDialogPresented)
        XCTAssertEqual(viewModel.total, 0)
        XCTAssertEqual(viewModel.session, 0)
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls.last, .reset(.counter))
        XCTAssertEqual(viewModel.unlocked.count, 4)
        XCTAssertEqual(viewModel.today, 21, "история по дням сохраняется")
        XCTAssertEqual(announcer.messages.last, "Counter: 0")
        XCTAssertEqual(viewModel.nextChapter?.id, "ch05")
    }

    func testResetAllClosesChapters() async {
        await setUp(makeState(total: 120, unlocked: ["ch01", "ch02", "ch03", "ch04"]))
        viewModel.reset(.all)
        XCTAssertEqual(viewModel.unlocked, [])
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls, [.reset(.all)])
        XCTAssertEqual(viewModel.unlocked, [])
        XCTAssertEqual(viewModel.openedCount, 0)
    }

    // MARK: - Главы и баннер

    func testUnlockShowsBannerAnnouncesAndVibrates() async {
        await setUp(makeState(total: 9))
        viewModel.tap()
        await viewModel.drainCommands()
        XCTAssertEqual(viewModel.banner?.chapterIDs, ["ch01"])
        XCTAssertTrue(viewModel.banner?.isSingle == true)
        XCTAssertEqual(viewModel.unlocked, ["ch01"])
        XCTAssertEqual(announcer.messages, ["Chapter open: Chapter ch01"])
        XCTAssertEqual(feedback.plans.last, ZikrFeedbackPlan(haptic: .success, playsSound: false))
        viewModel.exploreBanner()
        XCTAssertNil(viewModel.banner)
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls.last, .explore("ch01"))
    }

    func testMultipleChaptersFocusLast() async {
        // total 0, а глав ещё нет: следующее нажатие откроет сразу несколько (как evaluate()).
        var state = makeState(total: 59)
        state.unlocked = []
        await setUp(state)
        viewModel.tap()
        await viewModel.drainCommands()
        XCTAssertEqual(viewModel.banner?.chapterIDs, ["ch01", "ch02", "ch03"])
        XCTAssertEqual(viewModel.banner?.focusChapterID, "ch03")
        XCTAssertEqual(announcer.messages, ["New chapters open: 3"])
    }

    func testBannersOffStillAnnounces() async {
        await setUp(makeState(total: 9, settings: AppSettings(banners: false, lang: .en)))
        viewModel.tap()
        await viewModel.drainCommands()
        XCTAssertNil(viewModel.banner)
        XCTAssertEqual(announcer.messages.count, 1)
    }

    func testBannerAutoHides() async {
        await setUp(makeState(total: 9), bannerDuration: 0.05)
        viewModel.tap()
        await viewModel.drainCommands()
        XCTAssertNotNil(viewModel.banner)
        await waitUntil { self.viewModel.banner == nil }
    }

    // MARK: - Вибрация и звук (vibrate / tapSound)

    func testFeedbackFollowsSettings() async {
        await setUp(makeState(total: 31, unlocked: ["ch01", "ch02"], settings: AppSettings(haptics: true, sound: true, lang: .en)))
        viewModel.tap() // 32 → light + звук
        viewModel.tap() // 33 → medium + звук
        viewModel.undo() // → medium, без звука
        XCTAssertEqual(feedback.plans, [
            ZikrFeedbackPlan(haptic: .light, playsSound: true),
            ZikrFeedbackPlan(haptic: .medium, playsSound: true),
            ZikrFeedbackPlan(haptic: .medium, playsSound: false),
        ])
        await viewModel.drainCommands()
        XCTAssertEqual(feedback.plans.count, 3, "без новых глав — без вибрации success")
    }

    func testFeedbackPlanRespectsToggles() {
        let off = AppSettings(haptics: false, sound: false)
        XCTAssertEqual(ZikrFeedbackPlan.make(.tap(total: 33), settings: off), ZikrFeedbackPlan(haptic: nil, playsSound: false))
        let soundOnly = AppSettings(haptics: false, sound: true)
        XCTAssertEqual(ZikrFeedbackPlan.make(.tap(total: 1), settings: soundOnly), ZikrFeedbackPlan(haptic: nil, playsSound: true))
        XCTAssertEqual(ZikrFeedbackPlan.make(.unlock, settings: soundOnly), ZikrFeedbackPlan(haptic: nil, playsSound: false))
        let defaults = AppSettings()
        XCTAssertEqual(ZikrFeedbackPlan.make(.tap(total: 66), settings: defaults), ZikrFeedbackPlan(haptic: .medium, playsSound: false))
        XCTAssertEqual(ZikrFeedbackPlan.make(.tap(total: 67), settings: defaults), ZikrFeedbackPlan(haptic: .light, playsSound: false))
    }

    func testTapToneEnvelopeMatchesWebAudio() {
        XCTAssertEqual(TapTonePlayer.frequency, 660)
        XCTAssertEqual(TapTonePlayer.duration, 0.1)
        XCTAssertEqual(TapTonePlayer.gain(at: 0), 0.0001, accuracy: 1e-7)
        XCTAssertEqual(TapTonePlayer.gain(at: 0.01), 0.08, accuracy: 1e-4)
        XCTAssertEqual(TapTonePlayer.gain(at: 0.09), 0.0001, accuracy: 1e-6)
        XCTAssertLessThan(TapTonePlayer.gain(at: 0.05), 0.08)
        XCTAssertGreaterThan(TapTonePlayer.gain(at: 0.05), 0.0001)
    }

    // MARK: - Цель и история

    func testGoal() async {
        await setUp(makeState(total: 40, today: 40, settings: AppSettings(goalOn: true, goal: 100, lang: .en)))
        XCTAssertEqual(viewModel.goal?.goal, 100)
        XCTAssertEqual(viewModel.goal?.done, 40)
        XCTAssertEqual(viewModel.goal?.fraction ?? 0, 0.4, accuracy: 1e-9)
        for _ in 0..<70 { viewModel.tap() }
        XCTAssertEqual(viewModel.goal?.done, 100)
        XCTAssertEqual(viewModel.goal?.fraction, 1)
        await viewModel.drainCommands()
    }

    func testHistoryClearKeepsToday() async {
        var state = makeState(total: 30, today: 5)
        state.daily["2026-11-01"] = 20
        state.daily["2026-10-31"] = 5
        await setUp(state)
        XCTAssertEqual(viewModel.historyDays.map(\.day), [day, "2026-11-01", "2026-10-31"])
        viewModel.openHistory()
        viewModel.requestClearHistory()
        XCTAssertTrue(viewModel.isClearHistoryConfirmPresented)
        viewModel.confirmClearHistory()
        XCTAssertFalse(viewModel.isHistoryPresented)
        XCTAssertEqual(viewModel.historyDays.map(\.day), [day])
        await viewModel.drainCommands()
        XCTAssertEqual(sink.calls, [.clearHistory])
    }

    func testTapButtonWrapsLikeWebKit() {
        let font = UIFont.systemFont(ofSize: 17, weight: .bold)
        let wide = ZikrTapButton.greedyLines("Нажмите для зикра", font: font, width: 1_000)
        XCTAssertEqual(wide, "Нажмите для зикра")
        let narrow = ZikrTapButton.greedyLines("Нажмите для зикра", font: font, width: 140)
        XCTAssertEqual(narrow, "Нажмите для\nзикра", "жадный перенос, как в вебе")
        XCTAssertEqual(ZikrTapButton.greedyLines("Zikr", font: font, width: 1), "Zikr")
    }

    func testHistoryDateTextUsesAppLocale() {
        let ru = ZikrHistorySheet.dateText("2026-11-11", locale: Locale(identifier: "ru-RU"))
        XCTAssertTrue(ru.contains("2026") && ru.contains("11"), ru)
        XCTAssertTrue(ru.lowercased().contains("ноябр"), ru)
        let en = ZikrHistorySheet.dateText("2026-11-11", locale: Locale(identifier: "en-US"))
        XCTAssertEqual(en, "November 11, 2026")
        XCTAssertEqual(ZikrHistorySheet.dateText("bad", locale: Locale(identifier: "en-US")), "bad")
    }
}

@MainActor
final class SerialCommandQueueTests: XCTestCase {
    func testRunsInOrderAndCountsPending() async {
        let queue = SerialCommandQueue()
        var order: [Int] = []
        for i in 0..<50 {
            queue.enqueue {
                if i % 7 == 0 { try? await Task.sleep(nanoseconds: 1_000_000) }
                order.append(i)
            }
        }
        XCTAssertEqual(queue.pending, 50)
        await queue.drain()
        XCTAssertEqual(order, Array(0..<50))
        XCTAssertEqual(queue.pending, 0)
    }
}

final class WebZikrCommandSinkTests: XCTestCase {
    func testSnapshotScriptAlwaysReturnsStringOrNull() {
        let tap = WebZikrCommandSink.snapshotScript(method: "tap", arguments: [])
        XCTAssertEqual(tap, "(function(){try{var r=window.zikrNative&&window.zikrNative.tap();return r?JSON.stringify(r):null;}catch(e){return null;}})()")
        let reset = WebZikrCommandSink.snapshotScript(method: "reset", arguments: ["counter"])
        XCTAssertTrue(reset?.contains(#"window.zikrNative.reset("counter")"#) == true)
        // Аргумент экранируется JSONEncoder — инъекция невозможна.
        let evil = WebZikrCommandSink.snapshotScript(method: "reset", arguments: [#"x");alert(1);("#])
        XCTAssertTrue(evil?.contains(#"reset("x\");alert(1);(")"#) == true, evil ?? "")
    }

    func testDecode() {
        let snapshot = WebZikrCommandSink.decode(#"{"total":3,"today":2,"day":"2026-11-11","unlocked":[],"fresh":[],"updatedAt":9}"#)
        XCTAssertEqual(snapshot?.total, 3)
        XCTAssertNil(WebZikrCommandSink.decode("null"))
        XCTAssertNil(WebZikrCommandSink.decode("{}"))
    }

    @MainActor
    func testSinkRoutesThroughEvaluators() async {
        let web = FakeWebEvaluator()
        web.queryResult = #"{"total":1,"today":1,"day":"2026-11-11","unlocked":[],"fresh":[],"updatedAt":2}"#
        let sink = WebZikrCommandSink(queries: { web }, commands: { web })
        let snapshot = await sink.tap()
        XCTAssertEqual(snapshot?.total, 1)
        _ = await sink.undo()
        _ = await sink.reset(.all)
        let cleared = await sink.clearHistory()
        let explored = await sink.explore(chapterID: "ch01")
        XCTAssertTrue(cleared && explored)
        XCTAssertEqual(web.queries.count, 3)
        XCTAssertTrue(web.queries[2].contains(#"reset("all")"#))
        XCTAssertEqual(web.commands.count, 2)
        XCTAssertTrue(web.commands[0].contains("window.zikrNative.clearHistory()"))
        XCTAssertTrue(web.commands[1].contains(#"window.zikrNative.explore("ch01")"#))
        web.queryResult = nil
        let failed = await sink.tap()
        XCTAssertNil(failed)
    }
}

@MainActor
final class FakeWebEvaluator: WebQueryEvaluating, WebCommandEvaluating {
    var queries: [String] = []
    var commands: [String] = []
    var queryResult: String?
    var commandResult = true

    func evaluateQuery(_ script: String) async -> String? {
        queries.append(script)
        return queryResult
    }

    func evaluateCommand(_ script: String) async -> Bool {
        commands.append(script)
        return commandResult
    }
}
