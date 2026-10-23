// InfoContent.swift
// ZKR-48: тексты экрана «Инфо» на 6 языках — копия нужных ключей объекта UI из index.html
// (Resources/info-content.json, паритет проверяет InfoParityTests).

import Foundation
import ZikrCore

/// Ключи UI из index.html, которые использует экран «Инфо» (renderInfo / openLegend).
public enum InfoKey: String, CaseIterable, Sendable {
    case tabInfo = "tab.info"
    case about = "info.about"
    case aboutTextApp = "info.aboutTextApp"
    case how = "info.how"
    case howText = "info.howText"
    case sources = "info.sources"
    case sourcesText = "info.sourcesText"
    case privacy = "info.privacy"
    case privacyTextApp = "info.privacyTextApp"
    case legend = "map.legend"
    case disclaimer = "map.disclaimer"
    case legendPlace = "legend.place"
    case legendLit = "legend.lit"
    case legendRoute = "legend.route"
    case legendLife = "legend.life"
    case legendGesture = "legend.gesture"
    case legendList = "legend.list"
    case close = "common.close"
}

public struct InfoContent: Decodable, Equatable, Sendable {
    public static let supportedSchema = 1
    /// Язык запасного варианта — как `UI.en[key]` в T().
    public static let fallbackLanguage = "en"

    public let schema: Int
    /// languages[lang][key] = текст.
    public let languages: [String: [String: String]]

    public init(schema: Int = InfoContent.supportedSchema, languages: [String: [String: String]]) {
        self.schema = schema
        self.languages = languages
    }

    /// Порт T(key): UI[lang][key] ?? UI.en[key] ?? key.
    public func text(_ key: InfoKey, language: String) -> String {
        languages[language]?[key.rawValue]
            ?? languages[Self.fallbackLanguage]?[key.rawValue]
            ?? key.rawValue
    }

    /// JSON → InfoContent. Ошибки без содержимого файла: decoding / unsupportedSchema.
    public static func decode(from data: Data) throws -> InfoContent {
        let content: InfoContent
        do {
            content = try JSONDecoder().decode(InfoContent.self, from: data)
        } catch {
            throw AppError.decoding("InfoContent")
        }
        guard content.schema == supportedSchema else {
            throw AppError.unsupportedSchema(content.schema)
        }
        return content
    }
}
