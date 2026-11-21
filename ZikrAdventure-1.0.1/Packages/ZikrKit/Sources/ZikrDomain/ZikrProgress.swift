// ZikrProgress.swift
// ZKR-52: чистые функции карточки прогресса — порт 1:1 currentLevel() / progressCard() / nextChapter()
// и goalCard() из index.html. Без UI и локализации: экран только подставляет строки.

import Foundation

public enum ZikrProgress {
    /// Карточка уровня (progressCard()).
    public struct LevelCard: Equatable, Sendable {
        /// Индекс уровня 0…6 (`li`), при `isDone` — последний уровень.
        public let index: Int
        /// Номер для бейджа и «Уровень N из 7» (`li + 1`).
        public var number: Int { index + 1 }
        public let count: Int
        public let bounds: LevelCatalog.Bounds
        /// Все уровни пройдены (total ≥ 100 000 000): бейдж «★», шкала полная, без «до следующего».
        public let isDone: Bool
        /// Доля шкалы from–to, 0…1.
        public let fraction: Double
        /// «До следующего уровня»: max(0, to − total).
        public let toNext: Int64
    }

    /// Следующая глава: первая по порядку, которая ещё не открыта (nextChapter() — по unlocked, не по total).
    public struct NextChapter: Equatable, Sendable {
        public let id: String
        public let threshold: Int64
        /// «Повторений до главы»: max(0, n − total).
        public let remaining: Int64
    }

    /// currentLevel(): индекс первого уровня с total < to; если такого нет — число уровней (всё пройдено).
    public static func currentLevelIndex(total: Int64, levels: [LevelCatalog.Bounds] = LevelCatalog.levels) -> Int {
        levels.firstIndex { total < $0.to } ?? levels.count
    }

    public static func levelCard(total: Int64, levels: [LevelCatalog.Bounds] = LevelCatalog.levels) -> LevelCard {
        precondition(!levels.isEmpty)
        let li = currentLevelIndex(total: total, levels: levels)
        let done = li >= levels.count
        let index = min(li, levels.count - 1)
        let level = levels[index]
        let fraction: Double
        if done {
            fraction = 1
        } else {
            let raw = Double(total - level.from) / Double(level.to - level.from)
            fraction = min(1, max(0, raw))
        }
        return LevelCard(
            index: index,
            count: levels.count,
            bounds: level,
            isDone: done,
            fraction: fraction,
            toNext: max(0, level.to - total)
        )
    }

    public static func nextChapter(
        total: Int64,
        unlocked: [String],
        chapters: [(id: String, n: Int64)] = ChapterCatalog.thresholds
    ) -> NextChapter? {
        let open = Set(unlocked)
        guard let next = chapters.sorted(by: { $0.n < $1.n }).first(where: { !open.contains($0.id) }) else { return nil }
        return NextChapter(id: next.id, threshold: next.n, remaining: max(0, next.n - total))
    }

    /// «Открыто глав: X из Y» — state.unlocked.length (как в вебе, без фильтра).
    public static func openedCount(unlocked: [String]) -> Int {
        unlocked.count
    }

    /// Главы, которые откроются при этом total (evaluate()): n ≤ total и ещё не в unlocked, по порядку.
    public static func freshChapters(
        total: Int64,
        unlocked: [String],
        chapters: [(id: String, n: Int64)] = ChapterCatalog.thresholds
    ) -> [String] {
        let open = Set(unlocked)
        return chapters.sorted(by: { $0.n < $1.n }).filter { $0.n <= total && !open.contains($0.id) }.map(\.id)
    }

    /// goalCard(): nil — цель выключена (блок не показывается).
    public struct Goal: Equatable, Sendable {
        public let goal: Int64
        /// min(today, goal) — первое число «Личная цель: X из Y».
        public let done: Int64
        /// min(1, today / goal).
        public let fraction: Double
    }

    public static func goal(today: Int64, settings: AppSettings) -> Goal? {
        guard settings.goalOn, settings.goal > 0 else { return nil }
        let goal = Int64(settings.goal)
        return Goal(goal: goal, done: min(today, goal), fraction: min(1, Double(today) / Double(goal)))
    }

    /// История по дням (openHistory()): дни с n > 0, новые сверху, не больше 30.
    public static func historyDays(daily: [String: Int64], limit: Int = 30) -> [(day: String, count: Int64)] {
        daily.filter { $0.value > 0 }
            .sorted { $0.key > $1.key }
            .prefix(limit)
            .map { (day: $0.key, count: $0.value) }
    }
}
