// AppSettings.swift
// Настройки приложения — те же 11 полей и значения по умолчанию, что DEFAULT_SETTINGS в index.html.

import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case ru, en, uz, tg, kk, ky

    /// Порт detectLang(): первые две буквы первого предпочитаемого языка в нижнем регистре,
    /// если это один из 6 языков приложения, иначе "ru".
    public static func detect(preferredLanguages: [String]) -> AppLanguage {
        guard let first = preferredLanguages.first else { return .ru }
        let code = String(first.prefix(2)).lowercased()
        return AppLanguage(rawValue: code) ?? .ru
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var haptics: Bool
    public var sound: Bool
    public var animations: Bool
    public var banners: Bool
    public var translit: Bool
    public var translation: Bool
    public var keepAwake: Bool
    public var goalOn: Bool
    public var goal: Int
    public var preview: Bool
    public var lang: AppLanguage

    public init(
        haptics: Bool = true,
        sound: Bool = false,
        animations: Bool = true,
        banners: Bool = true,
        translit: Bool = true,
        translation: Bool = true,
        keepAwake: Bool = false,
        goalOn: Bool = false,
        goal: Int = 100,
        preview: Bool = false,
        lang: AppLanguage = .ru
    ) {
        self.haptics = haptics
        self.sound = sound
        self.animations = animations
        self.banners = banners
        self.translit = translit
        self.translation = translation
        self.keepAwake = keepAwake
        self.goalOn = goalOn
        self.goal = goal
        self.preview = preview
        self.lang = lang
    }

    /// DEFAULT_SETTINGS из index.html; lang — как detectLang().
    public static func defaults(preferredLanguages: [String]) -> AppSettings {
        AppSettings(lang: AppLanguage.detect(preferredLanguages: preferredLanguages))
    }
}
