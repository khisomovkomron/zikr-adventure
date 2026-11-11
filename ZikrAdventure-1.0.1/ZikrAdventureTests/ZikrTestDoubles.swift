// ZikrTestDoubles.swift
// ZKR-52: подставные зависимости ZikrViewModel — репозиторий прогресса, «веб» (единственный писатель счёта),
// вибрация/звук и VoiceOver.

import Foundation
import ZikrContent
import ZikrCore
import ZikrDomain
@testable import ZikrAdventure

actor FakeProgressRepository: ProgressRepository {
    private(set) var stored: ProgressState?
    private var continuations: [AsyncStream<ProgressState>.Continuation] = []

    init(_ stored: ProgressState?) {
        self.stored = stored
    }

    func load() -> ProgressState? { stored }

    func update(_ mutate: @Sendable (inout ProgressState) -> Void) throws -> ProgressState {
        var value = stored ?? ProgressState()
        mutate(&value)
        stored = value
        return value
    }

    func changes() -> AsyncStream<ProgressState> {
        let (stream, continuation) = AsyncStream.makeStream(of: ProgressState.self)
        continuations.append(continuation)
        return stream
    }

    /// Как запись веба через зеркало: файл меняется и подписчики получают значение.
    func emit(_ value: ProgressState) {
        stored = value
        continuations.forEach { $0.yield(value) }
    }

    var subscriberCount: Int { continuations.count }
}

/// Модель веб-страницы: тот же код, что zikrTap / zikrUndo / zikrReset в index.html.
@MainActor
final class FakeZikrSink: ZikrCommandSink {
    enum Call: Equatable {
        case tap, undo, reset(ZikrResetMode), clearHistory, explore(String)
    }

    var calls: [Call] = []
    var state: ProgressState
    var day: String
    /// Задержка ответа (имитация evaluateJavaScript).
    var delayNanoseconds: UInt64 = 0
    var fails = false
    /// Порядок, в котором веб выполнил нажатия (номер = total после нажатия).
    var appliedTotals: [Int64] = []

    init(state: ProgressState, day: String) {
        self.state = state
        self.day = day
    }

    func tap() async -> ZikrSnapshot? {
        calls.append(.tap)
        await pause()
        guard !fails else { return nil }
        state.total += 1
        state.daily[day, default: 0] += 1
        let fresh = ZikrProgress.freshChapters(total: state.total, unlocked: state.unlocked)
        state.unlocked += fresh
        appliedTotals.append(state.total)
        return persist(fresh)
    }

    func undo() async -> ZikrSnapshot? {
        calls.append(.undo)
        await pause()
        guard !fails, state.total > 0 else { return nil }
        state.total -= 1
        if let today = state.daily[day], today > 0 { state.daily[day] = today - 1 }
        return persist([])
    }

    func reset(_ mode: ZikrResetMode) async -> ZikrSnapshot? {
        calls.append(.reset(mode))
        await pause()
        guard !fails else { return nil }
        state.total = 0
        if mode == .all {
            state.unlocked = []
            state.viewed = []
        }
        return persist([])
    }

    func clearHistory() async -> Bool {
        calls.append(.clearHistory)
        state.daily = state.daily[day].map { [day: $0] } ?? [:]
        _ = persist([])
        return !fails
    }

    func explore(chapterID: String) async -> Bool {
        calls.append(.explore(chapterID))
        return !fails
    }

    private func pause() async {
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
    }

    private func persist(_ fresh: [String]) -> ZikrSnapshot {
        state.updatedAt = (state.updatedAt ?? 0) + 1
        return ZikrSnapshot(
            total: state.total,
            today: state.daily[day] ?? 0,
            day: day,
            unlocked: state.unlocked,
            fresh: fresh,
            updatedAt: state.updatedAt ?? 0
        )
    }
}

@MainActor
final class FakeZikrFeedback: ZikrFeedbackPerforming {
    var plans: [ZikrFeedbackPlan] = []
    func perform(_ plan: ZikrFeedbackPlan) { plans.append(plan) }
}

@MainActor
final class FakeAnnouncer: AccessibilityAnnouncing {
    var messages: [String] = []
    func announce(_ message: String) { messages.append(message) }
}

/// Минимальный контент: 7 уровней и главы с теми же порогами, что ChapterCatalog.
func testZikrContent() -> ZikrScreenContent {
    let levels = LevelCatalog.levels.enumerated().map { index, level in
        ZikrScreenContent.Level(from: level.from, to: level.to, name: ["ru": "Уровень \(index + 1)", "en": "Level name \(index + 1)"])
    }
    let chapters = ChapterCatalog.thresholds.map { chapter in
        ZikrScreenContent.Chapter(
            id: chapter.id,
            n: chapter.n,
            title: ["ru": "Глава \(chapter.id)", "en": "Chapter \(chapter.id)"],
            year: ["ru": "год \(chapter.id)", "en": "year \(chapter.id)"]
        )
    }
    return ZikrScreenContent(levels: levels, chapters: chapters)
}

struct FailingZikrContentProvider: ZikrContentProviding {
    func loadZikrContent() throws -> ZikrScreenContent {
        throw AppError.storageRead("zikr-content.json")
    }
}
