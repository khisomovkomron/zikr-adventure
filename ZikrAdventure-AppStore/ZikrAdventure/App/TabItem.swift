// TabItem.swift
// Определение вкладок приложения и их атрибутов (название, иконка, раздел веб-приложения).

import SwiftUI

enum TabItem: String, CaseIterable, Identifiable {
    case zikr
    case map
    case path
    case info
    case settings
    
    var id: String { rawValue }
    
    /// Локализованное название вкладки
    var title: LocalizedStringKey {
        switch self {
        case .zikr: return "tab.zikr"
        case .map: return "tab.map"
        case .path: return "tab.path"
        case .info: return "tab.info"
        case .settings: return "tab.settings"
        }
    }
    
    /// SF Symbol для иконки вкладки
    var systemImage: String {
        switch self {
        case .zikr: return "hand.tap.fill"
        case .map: return "map.fill"
        case .path: return "book.fill"
        case .info: return "info.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    /// ID раздела в веб-приложении (соответствует id элементов в index.html)
    var webSectionID: String {
        switch self {
        case .zikr: return "s-zikr"
        case .map: return "s-map"
        case .path: return "s-path"
        case .info: return "s-info"
        case .settings: return "s-settings"
        }
    }
}
