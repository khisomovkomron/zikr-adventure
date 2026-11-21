// LocalizationService.swift
// ZKR-50: язык нативных экранов. Источник — настройки веба (settings.lang): мост lang.change
// и снимки zikr-state.json; стартовое значение — UserDefaults "app.language" (как в 1.1.1).
// Тексты — Localizable.xcstrings (копия UI из index.html), бандл нужного .lproj, а не язык системы.
// Заменяет класс App/AppLanguage.swift (имя конфликтовало с ZikrDomain.AppLanguage).

import Foundation
import ZikrDomain

@MainActor
final class LocalizationService: ObservableObject {
    static let languageDefaultsKey = "app.language"

    @Published private(set) var language: AppLanguage

    private let bundleProvider: (AppLanguage) -> Bundle?
    private let defaults: UserDefaults?
    private var bundles: [AppLanguage: Bundle] = [:]

    /// - Parameters:
    ///   - language: стартовый язык; nil — из UserDefaults, иначе язык системы (detectLang).
    ///   - defaults: куда сохранять выбранный язык (nil — не сохранять, для тестов и превью).
    init(
        language: AppLanguage? = nil,
        defaults: UserDefaults? = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages,
        bundleProvider: @escaping (AppLanguage) -> Bundle? = LocalizationService.mainBundle(for:)
    ) {
        self.defaults = defaults
        self.bundleProvider = bundleProvider
        self.language = language
            ?? Self.language(code: defaults?.string(forKey: Self.languageDefaultsKey))
            ?? AppLanguage.detect(preferredLanguages: preferredLanguages)
    }

    /// Код языка из веба. Неизвестный код → ru (как LANG_CODES/detectLang).
    static func resolve(code: String) -> AppLanguage {
        AppLanguage(rawValue: code) ?? .ru
    }

    private static func language(code: String?) -> AppLanguage? {
        code.map(resolve(code:))
    }

    nonisolated static func mainBundle(for language: AppLanguage) -> Bundle? {
        Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    func setLanguage(code: String) {
        setLanguage(Self.resolve(code: code))
    }

    func setLanguage(_ newLanguage: AppLanguage) {
        defaults?.set(newLanguage.rawValue, forKey: Self.languageDefaultsKey)
        guard newLanguage != language else { return }
        language = newLanguage
    }

    /// Локаль чисел — как LANGS[].locale в index.html.
    var locale: Locale { Locale(identifier: Self.localeIdentifier(for: language)) }

    nonisolated static func localeIdentifier(for language: AppLanguage) -> String {
        switch language {
        case .ru: return "ru-RU"
        case .en: return "en-US"
        case .uz: return "uz-Latn-UZ"
        case .tg: return "tg-TJ"
        case .kk: return "kk-KZ"
        case .ky: return "ky-KG"
        }
    }

    /// Самоназвание языка — как LANGS[].name в index.html.
    nonisolated static func nativeName(of language: AppLanguage) -> String {
        switch language {
        case .ru: return "Русский"
        case .en: return "English"
        case .uz: return "O‘zbekcha"
        case .tg: return "Тоҷикӣ"
        case .kk: return "Қазақша"
        case .ky: return "Кыргызча"
        }
    }

    /// Строка на текущем языке; `%1$@`… подставляются строками (как T(key, ...args) в вебе).
    func tr(_ key: L10nKey, _ args: String...) -> String {
        let format = string(for: key, language: language)
        guard !args.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: args.map { $0 as CVarArg })
    }

    /// Число в локали языка (fmt() в вебе: toLocaleString(locale)).
    func format(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }

    /// ZKR-53: дробное число в локали языка — `toLocaleString(locale(), { maximumFractionDigits })` (км в distText()).
    func format(_ number: Double, maximumFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }

    func string(for key: L10nKey, language: AppLanguage) -> String {
        let missing = "\u{0}"
        if let bundle = bundle(for: language) {
            let value = bundle.localizedString(forKey: key.rawValue, value: missing, table: nil)
            if value != missing { return value }
        }
        if language != .en, let bundle = bundle(for: .en) {
            let value = bundle.localizedString(forKey: key.rawValue, value: missing, table: nil)
            if value != missing { return value }
        }
        return key.rawValue
    }

    private func bundle(for language: AppLanguage) -> Bundle? {
        if let cached = bundles[language] { return cached }
        let bundle = bundleProvider(language)
        bundles[language] = bundle
        return bundle
    }
}

extension TabItem {
    var titleKey: L10nKey {
        switch self {
        case .zikr: return .tabZikr
        case .map: return .tabMap
        case .path: return .tabPath
        case .info: return .tabInfo
        case .settings: return .tabSettings
        }
    }
}
