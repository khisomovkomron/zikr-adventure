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

    /// ZKR-61: зеркало, переданное до создания shared. Сам shared в App.init создавать нельзя:
    /// WebAppViewController → AuthCoordinator обращается к Firebase Auth, а FirebaseApp.configure()
    /// вызывается позже, в AppDelegate.
    private static var mirrorBeforeInit: WebStateMirror?
    private static var isSharedCreated = false

    private init() {
        let controller = WebAppViewController()
        viewController = controller
        controller.webViewManager = self
        controller.stateMirror = Self.mirrorBeforeInit
        Self.mirrorBeforeInit = nil
        Self.isSharedCreated = true
    }

    /// ZKR-61: подключает зеркало как можно раньше (из App.init), не создавая shared.
    /// Если shared уже есть — то же, что attachStateMirror.
    static func attachStateMirrorEarly(_ mirror: WebStateMirror?) {
        if isSharedCreated {
            shared.attachStateMirror(mirror)
        } else {
            mirrorBeforeInit = mirror
        }
    }

    /// ZKR-49: подключает зеркало веб-состояния (режим «тени»). nil — отключить.
    /// Если страница уже загружена, текущий снимок снимается сразу (см. WebAppViewController.stateMirror).
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
