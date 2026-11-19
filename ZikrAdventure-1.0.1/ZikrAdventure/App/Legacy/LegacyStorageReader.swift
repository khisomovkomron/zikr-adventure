import Foundation
import WebKit
import ZikrPersistence

@MainActor
protocol LegacyStorageReading {
    func read() async throws -> LegacySources
}

/// Только совместимость старого origin. Ни app index.html, ни мост, ни UI не загружаются.
/// Пустой результат допустим только после успешного чтения localStorage.
@MainActor
final class LegacyStorageReader: NSObject, LegacyStorageReading, WKNavigationDelegate {
    private let dataStore: WKWebsiteDataStore
    init(dataStore: WKWebsiteDataStore? = nil) { self.dataStore = dataStore ?? .default(); super.init() }
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<LegacySources, Error>?
    private var timeout: Task<Void, Never>?

    func read() async throws -> LegacySources {
        guard continuation == nil else { throw CocoaError(.coderInvalidValue) }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = dataStore
            configuration.setURLSchemeHandler(ReadOnlyMigrationPage(), forURLScheme: "zikr")
            let view = WKWebView(frame: .zero, configuration: configuration)
            webView = view
            view.navigationDelegate = self
            view.load(URLRequest(url: URL(string: "zikr://localhost/migration.html")!))
            timeout = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
                self?.finish(.failure(CocoaError(.fileReadUnknown)))
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("JSON.stringify({v2:localStorage.getItem('zikr-adventure.v2'),v1:localStorage.getItem('zikr-adventure.v1')})") { [weak self] value, error in
            guard let self else { return }
            if let error { self.finish(.failure(error)); return }
            struct Payload: Decodable { let v2: String?; let v1: String? }
            guard let text = value as? String, let data = text.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
                self.finish(.failure(CocoaError(.fileReadCorruptFile))); return
            }
            self.finish(.success(LegacySources(localStorageV2: payload.v2, localStorageV1: payload.v1)))
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(.failure(CocoaError(.fileReadUnknown))) }

    private func finish(_ result: Result<LegacySources, Error>) {
        guard let pending = continuation else { return }
        continuation = nil
        timeout?.cancel(); timeout = nil
        webView?.stopLoading(); webView?.navigationDelegate = nil; webView = nil
        pending.resume(with: result)
    }
}

final class ReadOnlyMigrationPage: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, url.host == "localhost", url.path == "/migration.html" else {
            task.didFailWithError(URLError(.unsupportedURL)); return
        }
        let data = Data("<!doctype html><meta charset='utf-8'><title>Migration</title>".utf8)
        task.didReceive(URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8"))
        task.didReceive(data); task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
