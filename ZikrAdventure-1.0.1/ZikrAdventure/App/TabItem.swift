// TabItem.swift
// Определение вкладок приложения и их атрибутов (название, иконка, веб-секция).

import SwiftUI

enum TabItem: String, CaseIterable, Identifiable {
    case zikr
    case map
    case path
    case info
    case settings
    
    var id: String { rawValue }
    
    /// Локализованное название вкладки (по умолчанию, если веб не передал язык)
    var fallbackTitle: String {
        switch self {
        case .zikr: return "Zikr"
        case .map: return "Map"
        case .path: return "Path"
        case .info: return "Info"
        case .settings: return "Settings"
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
    
    /// ID раздела в веб-приложении (используется для selectTab(id))
    var webID: String {
        return rawValue
    }
}
