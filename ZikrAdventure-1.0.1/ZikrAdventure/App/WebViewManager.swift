// WebViewManager.swift
// Единственный экземпляр WebAppViewController на всё приложение.
// Контроллер создаётся сразу в init, без ленивого fallback.
// ZKR-50: команды нативных экранов в веб (window.zikrNative.*) ждут загрузки страницы в очереди.

import UIKit
import ZikrPersistence

@MainActor
final class WebViewManager: WebCommandEvaluating {
    static let shared = WebViewManager()

    let viewController: WebAppViewController
    private var tabSelectionHandler: ((String) -> Void)?
    private var pendingSelectTab: String?
    /// ZKR-50: команды, пришедшие до загрузки страницы (или во время перезагрузки WebContent).
    private var pendingCommands: [(script: String, continuation: CheckedContinuation<Bool, Never>)] = []

    /// ZKR-61: зеркало, переданное до создания shared. shared создаётся при первом показе
    /// WebHostView (после FirebaseApp.configure() в AppDelegate); зеркало нужно раньше.
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

    /// ZKR-48: показан ли веб-онбординг (#onb). nil — страница не загружена или ответ не получен.
    func isOnboardingVisible() async -> Bool? {
        await viewController.isOnboardingVisible()
    }

    /// ZKR-50: выполняет команду сразу или после загрузки страницы (порядок сохраняется).
    func evaluateCommand(_ script: String) async -> Bool {
        if viewController.isWebViewLoaded, pendingCommands.isEmpty {
            return await viewController.evaluateCommand(script)
        }
        return await withCheckedContinuation { continuation in
            pendingCommands.append((script, continuation))
        }
    }

    func webViewDidLoad() {
        if let pending = pendingSelectTab {
            viewController.selectTab(pending)
            pendingSelectTab = nil
        }
        flushPendingCommands()
    }

    private func flushPendingCommands() {
        guard !pendingCommands.isEmpty else { return }
        let commands = pendingCommands
        pendingCommands = []
        Task { @MainActor in
            for command in commands {
                command.continuation.resume(returning: await viewController.evaluateCommand(command.script))
            }
        }
    }
}
