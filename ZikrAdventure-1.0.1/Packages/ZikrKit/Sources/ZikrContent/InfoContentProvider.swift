// InfoContentProvider.swift
// ZKR-48: источник контента «Инфо» (DI через AppContainer; в тестах/превью — подмена).

import Foundation
import ZikrCore

public protocol InfoContentProviding: Sendable {
    func loadContent() throws -> InfoContent
}

/// info-content.json из ресурсов модуля ZikrContent.
public struct BundledInfoContentProvider: InfoContentProviding {
    public static let resourceName = "info-content"
    private let url: URL?

    public init() {
        self.url = Bundle.module.url(forResource: Self.resourceName, withExtension: "json")
    }

    /// Явный путь к файлу (тесты).
    public init(url: URL) {
        self.url = url
    }

    public func loadContent() throws -> InfoContent {
        guard let url, let data = try? Data(contentsOf: url) else {
            throw AppError.storageRead("info-content.json")
        }
        return try InfoContent.decode(from: data)
    }
}

/// Готовый контент в памяти (превью, тесты).
public struct StaticInfoContentProvider: InfoContentProviding {
    private let content: InfoContent

    public init(_ content: InfoContent) {
        self.content = content
    }

    public func loadContent() throws -> InfoContent {
        content
    }
}
