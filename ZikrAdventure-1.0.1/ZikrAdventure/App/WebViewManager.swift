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
    private var pendingSelectTab: String?
    private var tabSelectionHandler: ((String) -> Void)?
    
    private init() {}
    
    /// Инициализирует WebAppViewController один раз
    func initialize(appLanguage: AppLanguage) {
        guard !isInitialized else { return }
        viewController = WebAppViewController()
        viewController?.appLanguage = appLanguage
        viewController?.webViewManager = self
        isInitialized = true
    }
    
    /// Устанавливает обработчик для изменений вкладки из веба
    func setTabSelectionHandler(_ handler: @escaping (String) -> Void) {
        tabSelectionHandler = handler
    }
    
    /// Вызывается вебом когда он переключает вкладку
    func notifyTabChange(_ tabID: String) {
        tabSelectionHandler?(tabID)
    }
    
    /// Переключает веб-приложение на указанную вкладку
    func selectTab(_ tabID: String) {
        guard let controller = viewController else { return }
        if controller.isWebViewLoaded {
            controller.selectTab(tabID)
        } else {
            pendingSelectTab = tabID
        }
    }
    
    /// Вызывается когда веб-страница загружена
    func webViewDidLoad() {
        if let pending = pendingSelectTab {
            viewController?.selectTab(pending)
            pendingSelectTab = nil
        }
    }
}
