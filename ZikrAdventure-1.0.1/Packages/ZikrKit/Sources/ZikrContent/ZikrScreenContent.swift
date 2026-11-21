// ZikrScreenContent.swift
// ZKR-52: тексты экрана «Зикр», которых нет в Localizable.xcstrings: названия уровней (LEVELS)
// и главы Сиры (CHAPTERS: название и год) на 6 языках. Файл zikr-content.json генерируется
// из index.html (node tools/zikr-content-from-web.mjs), руками не правится.
// ZKR-53: + для «Пути Сиры» — город, место, фокус и текст глав, карточки мест глав (PLACES), DIST, SAFA_MARWA.

import Foundation
import ZikrCore

public struct ZikrScreenContent: Codable, Equatable, Sendable {
    public struct Level: Codable, Equatable, Sendable {
        public let from: Int64
        public let to: Int64
        public let name: [String: String]

        public init(from: Int64, to: Int64, name: [String: String]) {
            self.from = from
            self.to = to
            self.name = name
        }
    }

    public struct Chapter: Codable, Equatable, Sendable {
        public let id: String
        public let n: Int64
        public let title: [String: String]
        public let year: [String: String]
        /// ZKR-53: "mecca" | "medina" | nil (глава без города — только лист, без карты).
        public let city: String?
        /// Ключ места (places): глава с местом показывается карточкой места (placeCard).
        public let place: String?
        /// Объект карты для главы без места (chapterFocus()).
        public let focus: String?
        /// Текст главы без места (chapterCard()).
        public let text: [String: String]?

        public init(
            id: String,
            n: Int64,
            title: [String: String],
            year: [String: String],
            city: String? = nil,
            place: String? = nil,
            focus: String? = nil,
            text: [String: String]? = nil
        ) {
            self.id = id
            self.n = n
            self.title = title
            self.year = year
            self.city = city
            self.place = place
            self.focus = focus
            self.text = text
        }
    }

    /// ZKR-53: место главы (PLACES[id] в index.html) — для карточки placeCard().
    public struct Place: Codable, Equatable, Sendable {
        /// Отрезок расстояния (DIST[id]): метры (0 — «центр карты»), сторона света, индекс Сафа/Марва.
        public struct Leg: Codable, Equatable, Sendable {
            public let m: Int64
            public let dir: String?
            public let sub: Int?

            public init(m: Int64, dir: String? = nil, sub: Int? = nil) {
                self.m = m
                self.dir = dir
                self.sub = sub
            }
        }

        public let ar: String
        public let city: String
        /// sacred | mosque | sira | nature | city | memorial (cat.* и иконка CAT_ICON).
        public let cat: String
        public let name: [String: String]
        public let sig: [String: String]
        public let look: [String: String]
        public let sira: [String: String]
        public let dist: [Leg]

        public init(
            ar: String,
            city: String,
            cat: String,
            name: [String: String],
            sig: [String: String],
            look: [String: String],
            sira: [String: String],
            dist: [Leg]
        ) {
            self.ar = ar
            self.city = city
            self.cat = cat
            self.name = name
            self.sig = sig
            self.look = look
            self.sira = sira
            self.dist = dist
        }
    }

    public let levels: [Level]
    /// По порядку порогов (как CH в вебе).
    public let chapters: [Chapter]
    /// ZKR-53: места глав по ключу.
    public let places: [String: Place]
    /// ZKR-53: подписи «Сафа», «Марва» по языкам (SAFA_MARWA).
    public let safaMarwa: [String: [String]]

    public init(
        levels: [Level],
        chapters: [Chapter],
        places: [String: Place] = [:],
        safaMarwa: [String: [String]] = [:]
    ) {
        self.levels = levels
        self.chapters = chapters
        self.places = places
        self.safaMarwa = safaMarwa
    }

    public static func decode(from data: Data) throws -> ZikrScreenContent {
        try JSONDecoder().decode(ZikrScreenContent.self, from: data)
    }

    /// tr(obj): язык → русский → пустая строка.
    public static func pick(_ values: [String: String], language: String) -> String {
        if let value = values[language], !value.isEmpty { return value }
        return values["ru"] ?? ""
    }

    public func levelName(index: Int, language: String) -> String {
        guard levels.indices.contains(index) else { return "" }
        return Self.pick(levels[index].name, language: language)
    }

    public func chapter(id: String) -> Chapter? {
        chapters.first { $0.id == id }
    }

    public func chapterTitle(id: String, language: String) -> String {
        chapter(id: id).map { Self.pick($0.title, language: language) } ?? ""
    }

    public func chapterYear(id: String, language: String) -> String {
        chapter(id: id).map { Self.pick($0.year, language: language) } ?? ""
    }

    /// Номер главы по порядку (c.index в вебе, с 1).
    public func chapterIndex(id: String) -> Int? {
        chapters.firstIndex { $0.id == id }.map { $0 + 1 }
    }

    /// Подпись «Сафа» / «Марва» (SAFA_MARWA[L()][sub]).
    public func safaMarwaLabel(_ sub: Int, language: String) -> String {
        let labels = safaMarwa[language] ?? safaMarwa["ru"] ?? []
        return labels.indices.contains(sub) ? labels[sub] : ""
    }
}

public protocol ZikrContentProviding: Sendable {
    func loadZikrContent() throws -> ZikrScreenContent
}

/// zikr-content.json из ресурсов модуля ZikrContent.
public struct BundledZikrContentProvider: ZikrContentProviding {
    public static let resourceName = "zikr-content"
    private let url: URL?

    public init() {
        self.url = Bundle.module.url(forResource: Self.resourceName, withExtension: "json")
    }

    public init(url: URL) {
        self.url = url
    }

    public func loadZikrContent() throws -> ZikrScreenContent {
        guard let url, let data = try? Data(contentsOf: url) else {
            throw AppError.storageRead("zikr-content.json")
        }
        return try ZikrScreenContent.decode(from: data)
    }
}

/// Готовый контент в памяти (превью, тесты).
public struct StaticZikrContentProvider: ZikrContentProviding {
    private let content: ZikrScreenContent

    public init(_ content: ZikrScreenContent) {
        self.content = content
    }

    public func loadZikrContent() throws -> ZikrScreenContent {
        content
    }
}
