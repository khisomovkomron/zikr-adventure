// WebAppViewController.swift
// Показывает встроенный интерфейс приложения в WKWebView и связывает его
// с нативными возможностями iPhone:
//  • "haptic"    — тактильный отклик (UIImpactFeedbackGenerator / UINotificationFeedbackGenerator);
//  • "keepAwake" — не гасить экран во время зикра;
//  • "save"      — копия прогресса в файле на устройстве (дополнительно к хранилищу страницы).
// Переходы на внешние сайты запрещены: приложение работает только со своими файлами.

import UIKit
import WebKit

final class WebAppViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private var webView: WKWebView?
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let progressStore = ProgressFileStore()
    private var pendingSectionID: String?
    private var isWebViewLoaded = false

    override func viewDidLoad() {
        super.viewDidLoad()
        let background = UIColor(named: "LaunchBackground") ?? .systemBackground
        view.backgroundColor = background

        let contentController = WKUserContentController()
        contentController.add(WeakScriptMessageHandler(target: self), name: "zikr")

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
        default:
            break
        }
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
        webView.reload()
    }
    
    /// Вызывается после завершения загрузки страницы.
    /// Если есть отложенное переключение раздела, выполняем его.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isWebViewLoaded = true
        if let sectionID = pendingSectionID {
            executeSectionSwitch(sectionID)
            pendingSectionID = nil
        }
    }
    
    // MARK: - Переключение разделов
    
    /// Переключает веб-приложение на указанный раздел (вкладку).
    /// Если страница ещё не загружена, команда будет выполнена после загрузки.
    func showSection(_ sectionID: String) {
        if isWebViewLoaded {
            executeSectionSwitch(sectionID)
        } else {
            pendingSectionID = sectionID
        }
    }
    
    private func executeSectionSwitch(_ sectionID: String) {
        let script = """
        (function() {
            const sections = document.querySelectorAll('.screen');
            sections.forEach(s => s.classList.remove('active'));
            const target = document.getElementById('\(sectionID)');
            if (target) target.classList.add('active');
            
            const tabs = document.querySelectorAll('.tab');
            tabs.forEach((tab, idx) => {
                const isActive = ['s-zikr','s-map','s-path','s-info','s-settings'][idx] === '\(sectionID)';
                tab.setAttribute('aria-selected', isActive ? 'true' : 'false');
            });
        })();
        """
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
