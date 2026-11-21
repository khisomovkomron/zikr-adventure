// SiraJourney.swift
// ZKR-53: чистые функции экрана «Путь Сиры» — порт 1:1 renderPath() / isOpen() / isReallyOpen() из index.html.
// Без UI и локализации: экран только подставляет строки.

import Foundation

public enum SiraJourney {
    /// Состояние заголовка уровня (`.lvl-head`, `.lvl-head.done`, `.lvl-head.active`).
    public enum LevelState: Equatable, Sendable {
        /// total ≥ to: бейдж «★».
        case done
        /// i == currentLevel(): navy-бейдж с номером.
        case active
        case upcoming
    }

    /// Группа уровня: заголовок и главы с from < n ≤ to (по порядку порогов).
    public struct Group: Equatable, Sendable {
        public let index: Int
        public var number: Int { index + 1 }
        public let bounds: LevelCatalog.Bounds
        public let state: LevelState
        public let chapterIDs: [String]
    }

    public static func groups(
        total: Int64,
        levels: [LevelCatalog.Bounds] = LevelCatalog.levels,
        chapters: [(id: String, n: Int64)] = ChapterCatalog.thresholds
    ) -> [Group] {
        let current = ZikrProgress.currentLevelIndex(total: total, levels: levels)
        let sorted = chapters.sorted { $0.n < $1.n }
        return levels.enumerated().map { i, level in
            let state: LevelState = total >= level.to ? .done : (i == current ? .active : .upcoming)
            let ids = sorted.filter { $0.n > level.from && $0.n <= level.to }.map(\.id)
            return Group(index: i, bounds: level, state: state, chapterIDs: ids)
        }
    }

    /// isOpen(): глава открыта или включён «Предпросмотр» (settings.preview).
    public static func isOpen(_ id: String, unlocked: [String], preview: Bool) -> Bool {
        preview || unlocked.contains(id)
    }

    /// isReallyOpen(): только открытые счётом главы.
    public static func isReallyOpen(_ id: String, unlocked: [String]) -> Bool {
        unlocked.contains(id)
    }

    /// Метка «Новое»: глава реально открыта и ещё не просмотрена (без учёта предпросмотра).
    public static func isNew(_ id: String, unlocked: [String], viewed: some Collection<String>) -> Bool {
        isReallyOpen(id, unlocked: unlocked) && !viewed.contains(id)
    }
}

/// ZKR-53: команды экрана «Путь Сиры» в веб (window.zikrNative.*). Веб — единственный писатель viewed / city.
public protocol SiraCommandSink: Sendable {
    /// «Читать»: отметить главу просмотренной (markViewed() в chapterCard / placeCard).
    @discardableResult func markViewed(chapterID: String) async -> Bool
    /// «На карте» в строке главы (data-go): markViewed + openCity(city, chapterFocus(ch)) → вкладка «Карта».
    @discardableResult func showChapter(chapterID: String) async -> Bool
    /// «На карте» в листе главы (#card-map → explore(ch)): карта города и лист главы на ней.
    @discardableResult func explore(chapterID: String) async -> Bool
}
