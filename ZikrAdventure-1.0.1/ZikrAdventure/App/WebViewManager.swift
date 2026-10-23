// WebViewManager.swift
// Менеджер единственного экземпляра WKWebView, который живёт на протяжении всей сессии приложения.
// Решает проблему множественных экземпляров (множественные AuthCoordinator, divergence состояния).
// WebView создаётся один раз и переиспользуется между вкладками.

import UIKit
import WebKit

@MainActor
class WebViewManager: ObservableObject {
    static let shared = WebViewManager()
    
    private(set) var viewController: WebAppViewController?
    private var isInitialized = false
    
    private init() {}
    
    /// Инициализирует WebAppViewController один раз
    func initialize(appLanguage: AppLanguage) {
        guard !isInitialized else { return }
        viewController = WebAppViewController()
        viewController?.appLanguage = appLanguage
        isInitialized = true
    }
    
    /// Переключает веб-приложение на указанную вкладку
    func selectTab(_ tabID: String) {
        viewController?.selectTab(tabID)
    }
}
