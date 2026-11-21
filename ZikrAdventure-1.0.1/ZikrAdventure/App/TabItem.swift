// TabItem.swift
// Определение вкладок приложения и их атрибутов (иконка, веб-секция).
// ZKR-50: названия — Localizable.xcstrings (LocalizationService, TabItem.titleKey).
// Иконки — те же SVG, что в index.html (P.beads / map / path / info / gear).

import SwiftUI

enum TabItem: String, CaseIterable, Identifiable {
    case zikr
    case map
    case path
    case info
    case settings

    var id: String { rawValue }

    /// Имя vector-ассета (24×24 stroke SVG из веб-набора P)
    var iconName: String {
        switch self {
        case .zikr: return "TabBeads"
        case .map: return "TabMap"
        case .path: return "TabPath"
        case .info: return "TabInfo"
        case .settings: return "TabGear"
        }
    }

    /// ID раздела в веб-приложении (используется для selectTab(id))
    var webID: String {
        return rawValue
    }
}
