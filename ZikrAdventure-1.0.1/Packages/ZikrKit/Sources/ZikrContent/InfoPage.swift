// InfoPage.swift
// ZKR-48: модель экрана «Инфо» — пункты и легенда в том же порядке и с теми же иконками,
// что renderInfo() / openLegend() в index.html (вариант IS_APP).

import Foundation

/// Иконки из набора P в index.html (24×24 stroke SVG).
public enum InfoIcon: String, Sendable {
    case info, path, book, lock, map, star, urban, hand, list
}

public enum InfoTopicID: String, CaseIterable, Sendable {
    case about, how, sources, privacy
}

/// Пункт списка, открывающий лист с заголовком и текстом.
public struct InfoTopic: Equatable, Sendable, Identifiable {
    public let id: InfoTopicID
    public let icon: InfoIcon
    public let title: String
    public let body: String
}

/// Строка списка без действия (ведёт в легенду) — заголовок и иконка.
public struct InfoRow: Equatable, Sendable {
    public let icon: InfoIcon
    public let title: String
}

public struct InfoLegendEntry: Equatable, Sendable, Identifiable {
    public let id: String
    public let icon: InfoIcon
    public let text: String
}

public struct InfoLegend: Equatable, Sendable {
    public let title: String
    public let disclaimer: String
    public let entries: [InfoLegendEntry]
}

public struct InfoPage: Equatable, Sendable {
    public let title: String
    public let topics: [InfoTopic]
    public let legendRow: InfoRow
    public let legend: InfoLegend
    public let closeTitle: String

    public static func make(content: InfoContent, language: String) -> InfoPage {
        func t(_ key: InfoKey) -> String { content.text(key, language: language) }

        let topics: [(InfoTopicID, InfoIcon, InfoKey, InfoKey)] = [
            (.about, .info, .about, .aboutTextApp),
            (.how, .path, .how, .howText),
            (.sources, .book, .sources, .sourcesText),
            (.privacy, .lock, .privacy, .privacyTextApp),
        ]
        let legendEntries: [(InfoIcon, InfoKey)] = [
            (.info, .legendPlace),
            (.star, .legendLit),
            (.path, .legendRoute),
            (.urban, .legendLife),
            (.hand, .legendGesture),
            (.list, .legendList),
        ]
        return InfoPage(
            title: t(.tabInfo),
            topics: topics.map { InfoTopic(id: $0.0, icon: $0.1, title: t($0.2), body: t($0.3)) },
            legendRow: InfoRow(icon: .map, title: t(.legend)),
            legend: InfoLegend(
                title: t(.legend),
                disclaimer: t(.disclaimer),
                entries: legendEntries.map { InfoLegendEntry(id: $0.1.rawValue, icon: $0.0, text: t($0.1)) }
            ),
            closeTitle: t(.close)
        )
    }
}
