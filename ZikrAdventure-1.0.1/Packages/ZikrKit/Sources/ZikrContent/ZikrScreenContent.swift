// ZikrScreenContent.swift
// ZKR-52: тексты экрана «Зикр», которых нет в Localizable.xcstrings: названия уровней (LEVELS)
// и главы Сиры (CHAPTERS: название и год) на 6 языках. Файл zikr-content.json генерируется
// из index.html (node tools/zikr-content-from-web.mjs), руками не правится.

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

        public init(id: String, n: Int64, title: [String: String], year: [String: String]) {
            self.id = id
            self.n = n
            self.title = title
            self.year = year
        }
    }

    public let levels: [Level]
    /// По порядку порогов (как CH в вебе).
    public let chapters: [Chapter]

    public init(levels: [Level], chapters: [Chapter]) {
        self.levels = levels
        self.chapters = chapters
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
