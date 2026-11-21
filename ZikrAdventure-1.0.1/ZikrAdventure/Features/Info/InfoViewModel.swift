// InfoViewModel.swift
// ZKR-48: состояние нативного экрана «Инфо»: страница на текущем языке и открытый лист.
// Контент — ZikrContent (копия текстов index.html), язык — AppLanguage (мост lang.change).

import Foundation
import os
import ZikrContent
import ZikrDomain

/// Открытый лист экрана «Инфо».
enum InfoSheet: Equatable, Identifiable {
    case topic(InfoTopicID)
    case legend

    var id: String {
        switch self {
        case .topic(let topic): return "topic.\(topic.rawValue)"
        case .legend: return "legend"
        }
    }
}

@MainActor
final class InfoViewModel: ObservableObject {
    @Published private(set) var page: InfoPage?
    @Published private(set) var sheet: InfoSheet?
    /// Настройка «Анимации» (zikr-state.json, зеркало веб-состояния). Системный Reduce Motion
    /// учитывается во view.
    @Published private(set) var animationsEnabled = true

    private let content: InfoContent?
    private let settings: (any SettingsRepository)?
    private var language: String

    private static let logger = Logger(subsystem: "com.komronkhisomov.zikradventure", category: "info")

    init(provider: any InfoContentProviding, settings: (any SettingsRepository)?, language: String) {
        self.settings = settings
        self.language = language
        do {
            let content = try provider.loadContent()
            self.content = content
            self.page = InfoPage.make(content: content, language: language)
        } catch {
            // Без контента экран остаётся веб-версией (как в 1.1.1).
            Self.logger.error("Info content unavailable: \(String(describing: error), privacy: .public)")
            self.content = nil
            self.page = nil
        }
    }

    /// false — контент не загрузился, показывается веб-экран.
    var isAvailable: Bool { page != nil }

    func setLanguage(_ language: String) {
        guard language != self.language, let content else { return }
        self.language = language
        page = InfoPage.make(content: content, language: language)
    }

    func topic(_ id: InfoTopicID) -> InfoTopic? {
        page?.topics.first { $0.id == id }
    }

    func open(_ sheet: InfoSheet) {
        self.sheet = sheet
    }

    func closeSheet() {
        sheet = nil
    }

    func refreshSettings() async {
        guard let settings else { return }
        if let loaded = await settings.load() {
            animationsEnabled = loaded.animations
        }
    }
}
