// WebViewManager.swift
// Менеджер единственного экземпляра WKWebView, который живёт на протяжении всей сессии приложения.
// WebView создаётся один раз при инициализации менеджера.

import UIKit
import WebKit

@MainActor
class WebViewManager: ObservableObject {
    static let shared = WebViewManager()
    
    let viewController: WebAppViewController
    private var tabSelectionHandler: ((String) -> Void)?
    private var pendingSelectTab: String?
    
    private init() {
        self.viewController = WebAppViewController()
    }
    
    /// Устанавливает AppLanguage после инициализации
    func setAppLanguage(_ appLanguage: AppLanguage) {
        viewController.appLanguage = appLanguage
    }
    
    /// Устанавливает обработчик для изменений вкладки из веба
    func setTabSelectionHandler(_ handler: @escaping (String) -> Void) {
        tabSelectionHandler = handler
        viewController.webViewManager = self
    }
    
    /// Вызывается вебом когда он переключает вкладку
    func notifyTabChange(_ tabID: String) {
        tabSelectionHandler?(tabID)
    }
    
    /// Переключает веб-приложение на указанную вкладку
    func selectTab(_ tabID: String) {
        if viewController.isWebViewLoaded {
            viewController.selectTab(tabID)
        } else {
            pendingSelectTab = tabID
        }
    }
    
    /// Вызывается когда веб-страница загружена
    func webViewDidLoad() {
        if let pending = pendingSelectTab {
            viewController.selectTab(pending)
            pendingSelectTab = nil
        }
    }
}
