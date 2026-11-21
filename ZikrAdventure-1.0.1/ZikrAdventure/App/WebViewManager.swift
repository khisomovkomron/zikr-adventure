// WebViewManager.swift
// Единственный экземпляр WebAppViewController на всё приложение.
// Контроллер создаётся сразу в init, без ленивого fallback.
// ZKR-50: команды нативных экранов в веб (window.zikrNative.*) ждут загрузки страницы в очереди.

import UIKit
import ZikrPersistence

@MainActor
final class WebViewManager: WebCommandEvaluating, WebQueryEvaluating {
    static let shared = WebViewManager()

    let viewController: WebAppViewController
    private var tabSelectionHandler: ((String) -> Void)?
    private var pendingSelectTab: String?
    /// ZKR-50: команды, пришедшие до загрузки страницы (или во время перезагрузки WebContent).
    /// ZKR-52: и запросы со строковым ответом (снимок счётчика) — в той же очереди, порядок общий.
    private var pendingCommands: [PendingCommand] = []

    private enum PendingCommand {
        case command(String, CheckedContinuation<Bool, Never>)
        case query(String, CheckedContinuation<String?, Never>)
    }

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
        if viewController.isWebViewLoaded, pendingCommands.isEmpty, !isFlushing {
            return await viewController.evaluateCommand(script)
        }
        return await withCheckedContinuation { continuation in
            pendingCommands.append(.command(script, continuation))
        }
    }

    /// ZKR-52: то же для команды со строковым (JSON) ответом.
    func evaluateQuery(_ script: String) async -> String? {
        if viewController.isWebViewLoaded, pendingCommands.isEmpty, !isFlushing {
            return await viewController.evaluateQuery(script)
        }
        return await withCheckedContinuation { continuation in
            pendingCommands.append(.query(script, continuation))
        }
    }

    func webViewDidLoad() {
        if let pending = pendingSelectTab {
            viewController.selectTab(pending)
            pendingSelectTab = nil
        }
        flushPendingCommands()
    }

    /// ZKR-52: пока очередь сбрасывается, новые команды тоже встают в неё (иначе быстрые нажатия
    /// могли бы обогнать ожидающие команды).
    private var isFlushing = false

    private func flushPendingCommands() {
        guard !pendingCommands.isEmpty, !isFlushing else { return }
        isFlushing = true
        Task { @MainActor in
            defer { isFlushing = false }
            while !pendingCommands.isEmpty, viewController.isWebViewLoaded {
                let command = pendingCommands.removeFirst()
                switch command {
                case .command(let script, let continuation):
                    continuation.resume(returning: await viewController.evaluateCommand(script))
                case .query(let script, let continuation):
                    continuation.resume(returning: await viewController.evaluateQuery(script))
                }
            }
        }
    }
}
