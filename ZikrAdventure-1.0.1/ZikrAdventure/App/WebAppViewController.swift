// WebAppViewController.swift
// Показывает встроенный интерфейс приложения в WKWebView и связывает его
// с нативными возможностями iPhone:
//  • "haptic"    — тактильный отклик (UIImpactFeedbackGenerator / UINotificationFeedbackGenerator);
//  • "keepAwake" — не гасить экран во время зикра;
//  • "save"      — копия прогресса в файле на устройстве (дополнительно к хранилищу страницы);
//  • "auth.*"    — авторизация через Google и Apple (v1.1.0).
// Переходы на внешние сайты запрещены: приложение работает только со своими файлами.
// Команды auth принимаются только из основного доверенного документа zikr://localhost.

import UIKit
import WebKit
import SafariServices
import os
import ZikrPersistence

final class WebAppViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private var webView: WKWebView?
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let progressStore = ProgressFileStore()
    private let authCoordinator = AuthCoordinator()
    var isWebViewLoaded = false
    var appLanguage: AppLanguage?
    weak var webViewManager: WebViewManager?
    /// ZKR-61: если зеркало подключено уже после загрузки страницы, текущий снимок
    /// снимается сразу (replay), а не ждёт следующего "save".
    var stateMirror: WebStateMirror? {
        didSet {
            guard stateMirror !== oldValue, isWebViewLoaded, let webView else { return }
            LegacyWebStateImporter.capture(from: webView, into: stateMirror)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let background = UIColor(named: "LaunchBackground") ?? .systemBackground
        view.backgroundColor = background

        let contentController = WKUserContentController()
        contentController.add(WeakScriptMessageHandler(target: self), name: "zikr")
        
        // Подписываемся на изменения состояния авторизации
        authCoordinator.onStateChange = { [weak self] state in
            self?.sendAuthStateToWeb(state)
        }

        // Сохранённый прогресс передаётся странице ещё до запуска её скриптов.
        let restoreScript = WKUserScript(
            source: "window.__ZIKR_NATIVE_STATE = \(progressStore.loadJSONLiteral());",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(restoreScript)
        
        // Скрываем веб-табbar, так как используем нативный
        let hideTabbarScript = WKUserScript(
            source: """
            window.__ZIKR_NATIVE_TABS = true;
            document.addEventListener('DOMContentLoaded', () => {
                const tabbar = document.getElementById('tabbar');
                if (tabbar) tabbar.style.display = 'none';
            });
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(hideTabbarScript)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.websiteDataStore = .default()
        configuration.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: BundleSchemeHandler.scheme)

        let webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.backgroundColor = background
        webView.scrollView.backgroundColor = background
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsLinkPreview = false
        webView.navigationDelegate = self
        view.addSubview(webView)
        self.webView = webView

        if let url = URL(string: "\(BundleSchemeHandler.scheme)://localhost/index.html") {
            webView.load(URLRequest(url: url))
        }
        lightImpact.prepare()
    }

    // MARK: - Сообщения со страницы

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        // Issue 12: Accept auth commands only from trusted main-frame document
        guard message.frameInfo.isMainFrame else { return }
        guard message.frameInfo.request.url?.scheme == BundleSchemeHandler.scheme,
              message.frameInfo.request.url?.host == "localhost" else { return }
        
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "haptic":
            switch body["style"] as? String {
            case "medium":
                mediumImpact.impactOccurred()
            case "success":
                notificationFeedback.notificationOccurred(.success)
            case "warning":
                notificationFeedback.notificationOccurred(.warning)
            default:
                lightImpact.impactOccurred()
                lightImpact.prepare()
            }
        case "keepAwake":
            UIApplication.shared.isIdleTimerDisabled = (body["on"] as? Bool) ?? false
        case "save":
            if let json = body["data"] as? String {
                progressStore.save(json: json)
                stateMirror?.enqueue(json)
            }
        case "auth.signInGoogle":
            handleAuthMessage { await self.authCoordinator.signInWithGoogle(presentingViewController: self) }
        case "auth.signInApple":
            handleAuthMessage { await self.authCoordinator.signInWithApple() }
        case "auth.signOut":
            handleAuthMessage { try await self.authCoordinator.signOut() }
        case "auth.deleteAccount":
            handleAuthMessage { try await self.authCoordinator.deleteAccount(presentingViewController: self) }
        case "auth.getState":
            sendAuthStateToWeb(authCoordinator.state)
        case "openURL":
            if let urlString = body["url"] as? String,
               let url = URL(string: urlString),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                Task { @MainActor in
                    let safari = SFSafariViewController(url: url)
                    self.present(safari, animated: true)
                }
            }
        case "lang.change":
            if let lang = body["lang"] as? String,
               let titles = body["tabs"] as? [String: String] {
                appLanguage?.update(lang: lang, titles: titles)
            }
        case "tab.change":
            if let tabID = body["tab"] as? String {
                webViewManager?.notifyTabChange(tabID)
            }
        default:
            break
        }
    }
    
    private func handleAuthMessage(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                // Issue 4: Surface errors - send error state to web
                if let nsError = error as NSError? {
                    // ZKR-23: логируем реальную ошибку
                    authLogger.error("Auth action failed (domain: \(nsError.domain, privacy: .public), code: \(nsError.code, privacy: .public))")
                    let isOffline = nsError.domain == NSURLErrorDomain ||
                                    nsError.localizedDescription.contains("offline")
                    let message = isOffline ? "offline" : "error"
                    let errorState = AuthState.error(message: message, retryable: true)
                    sendAuthStateToWeb(errorState)
                }
            }
        }
    }
    
    // Issue 11: Use JSONEncoder for proper JSON serialization (XSS protection)
    private struct AuthStatePayload: Codable {
        let state: String
        let user: UserPayload?
        let message: String?
        let retryable: Bool?
        let provider: String?
        
        struct UserPayload: Codable {
            let uid: String
            let displayName: String?
            let email: String?
            let provider: String
        }
    }
    
    private func sendAuthStateToWeb(_ state: AuthState) {
        let payload: AuthStatePayload
        
        switch state {
        case .guest:
            payload = AuthStatePayload(state: "guest", user: nil, message: nil, retryable: nil, provider: nil)
        case .signingIn(let provider):
            payload = AuthStatePayload(state: "signingIn", user: nil, message: nil, retryable: nil, provider: provider)
        case .signedIn(let user):
            let userPayload = AuthStatePayload.UserPayload(
                uid: user.uid,
                displayName: user.displayName,
                email: user.email,
                provider: user.provider
            )
            payload = AuthStatePayload(state: "signedIn", user: userPayload, message: nil, retryable: nil, provider: nil)
        case .error(let message, let retryable):
            payload = AuthStatePayload(state: "error", user: nil, message: message, retryable: retryable, provider: nil)
        case .deleting:
            payload = AuthStatePayload(state: "deleting", user: nil, message: nil, retryable: nil, provider: nil)
        }
        
        guard let jsonData = try? JSONEncoder().encode(payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let script = "window.dispatchEvent(new CustomEvent('zikr:auth', { detail: \(jsonString) }));"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    // MARK: - Навигация: разрешены только встроенные страницы

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let allowed = navigationAction.request.url?.scheme == BundleSchemeHandler.scheme
        decisionHandler(allowed ? .allow : .cancel)
    }

    /// Если процесс веб-страницы был выгружен системой (нехватка памяти), перезагружаем её.
    /// Прогресс не теряется: он хранится в хранилище страницы и в файле на устройстве.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.addUserScript(WKUserScript(
            source: "window.__ZIKR_NATIVE_STATE = \(progressStore.loadJSONLiteral());",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        webView.configuration.userContentController.addUserScript(WKUserScript(
            source: """
            window.__ZIKR_NATIVE_TABS = true;
            document.addEventListener('DOMContentLoaded', () => {
                const tabbar = document.getElementById('tabbar');
                if (tabbar) tabbar.style.display = 'none';
            });
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        webView.reload()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isWebViewLoaded = true
        webViewManager?.webViewDidLoad()
        LegacyWebStateImporter.capture(from: webView, into: stateMirror)
    }
    
    // MARK: - Переключение вкладок
    
    /// Переключает веб-приложение на указанную вкладку через selectTab()
    func selectTab(_ tabID: String) {
        guard isWebViewLoaded else { return }
        let script = "if (typeof selectTab === 'function') selectTab('\(tabID)');"
        webView?.evaluateJavaScript(script)
    }
}

/// Слабая ссылка на обработчик сообщений, чтобы WKUserContentController
/// не удерживал контроллер в памяти навсегда.
@MainActor
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
