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

final class WebAppViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private var webView: WKWebView?
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let progressStore = ProgressFileStore()
    private let authCoordinator = AuthCoordinator()

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
        default:
            break
        }
    }
    
    private func handleAuthMessage(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                // Ошибки обрабатываются в authCoordinator и отправляются через onStateChange
            }
        }
    }
    
    private func sendAuthStateToWeb(_ state: AuthState) {
        let stateJSON: String
        
        switch state {
        case .guest:
            stateJSON = """
            {"state":"guest"}
            """
        case .signingIn(let provider):
            stateJSON = """
            {"state":"signingIn","provider":"\(provider)"}
            """
        case .signedIn(let user):
            let name = user.displayName?.replacingOccurrences(of: "\"", with: "\\\"") ?? ""
            let email = user.email?.replacingOccurrences(of: "\"", with: "\\\"") ?? ""
            stateJSON = """
            {"state":"signedIn","user":{"uid":"\(user.uid)","displayName":\(name.isEmpty ? "null" : "\"\(name)\""),"email":\(email.isEmpty ? "null" : "\"\(email)\""),"provider":"\(user.provider)"}}
            """
        case .error(let message, let retryable):
            stateJSON = """
            {"state":"error","message":"\(message)","retryable":\(retryable)}
            """
        case .deleting:
            stateJSON = """
            {"state":"deleting"}
            """
        }
        
        let script = "window.dispatchEvent(new CustomEvent('zikr:auth', { detail: \(stateJSON) }));"
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
        webView.reload()
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
