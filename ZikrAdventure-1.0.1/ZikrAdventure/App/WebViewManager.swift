// WebViewManager.swift
// Единственный экземпляр WebAppViewController на всё приложение.
// Контроллер создаётся сразу в init, без ленивого fallback.

import UIKit
import ZikrPersistence

@MainActor
final class WebViewManager {
    static let shared = WebViewManager()

    let viewController: WebAppViewController
    private var tabSelectionHandler: ((String) -> Void)?
    private var pendingSelectTab: String?

    private init() {
        let controller = WebAppViewController()
        viewController = controller
        controller.webViewManager = self
    }

    /// ZKR-49: подключает зеркало веб-состояния (режим «тени»). nil — отключить.
    func attachStateMirror(_ mirror: WebStateMirror?) {
        viewController.stateMirror = mirror
    }

    func setTabSelectionHandler(_ handler: @escaping (String) -> Void) {
        tabSelectionHandler = handler
    }

    func notifyTabChange(_ tabID: String) {
        tabSelectionHandler?(tabID)
    }

    func selectTab(_ tabID: String) {
        if viewController.isWebViewLoaded {
            viewController.selectTab(tabID)
        } else {
            pendingSelectTab = tabID
        }
    }

    func webViewDidLoad() {
        if let pending = pendingSelectTab {
            viewController.selectTab(pending)
            pendingSelectTab = nil
        }
    }
}
