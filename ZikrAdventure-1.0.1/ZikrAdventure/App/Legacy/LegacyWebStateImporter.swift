// LegacyWebStateImporter.swift
// Снимок состояния веб-страницы после загрузки (ZKR-49, режим «тени»).
// Только чтение: скрипт ничего не меняет на странице и в localStorage.

import Foundation
import WebKit
import ZikrPersistence

@MainActor
enum LegacyWebStateImporter {
    /// Только чтение. Выполняется в page world после didFinish главного фрейма.
    static let script = """
    (function(){ try {
      var live = (typeof state === 'object' && state) ? JSON.stringify(state) : null;
      return JSON.stringify({ live: live,
        v2: localStorage.getItem('zikr-adventure.v2'),
        v1: localStorage.getItem('zikr-adventure.v1') });
    } catch (e) { return null; } })()
    """

    private struct Payload: Decodable {
        let live: String?
        let v2: String?
        let v1: String?
    }

    /// live != nil → mirror.enqueue(live); иначе → mirror.enqueueFallback(v2, v1, progress.json),
    /// что приводит к store.bootstrap (существующий файл не перезаписывается).
    static func capture(from webView: WKWebView, into mirror: WebStateMirror?) {
        guard AppContainer.isWebMirrorEnabled, let mirror else { return }
        webView.evaluateJavaScript(script) { result, _ in
            guard let text = result as? String,
                  let data = text.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
            if let live = payload.live {
                mirror.enqueue(live)
            } else {
                var sources = AppContainer.legacyProgressFileURL()
                    .map { LegacySources.progressFile(at: $0) } ?? LegacySources()
                sources.localStorageV2 = payload.v2
                sources.localStorageV1 = payload.v1
                mirror.enqueueFallback(sources)
            }
        }
    }
}
