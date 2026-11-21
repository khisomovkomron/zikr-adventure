// WebSiraCommandSink.swift
// ZKR-53: команды экрана «Путь Сиры» в веб. Единственный писатель viewed / city — страница:
// window.zikrNative.markViewed / showChapter / explore (index.html) выполняют тот же код, что веб-кнопки
// «Читать» и «На карте», и сохраняют состояние (persist() → "save" → progress.json + zikr-state.json).
// До загрузки страницы команды ждут в очереди WebViewManager.

import Foundation
import ZikrDomain

@MainActor
final class WebSiraCommandSink: SiraCommandSink {
    private let commands: () -> any WebCommandEvaluating

    init(commands: @escaping () -> any WebCommandEvaluating) {
        self.commands = commands
    }

    func markViewed(chapterID: String) async -> Bool { await run("markViewed", chapterID) }
    func showChapter(chapterID: String) async -> Bool { await run("showChapter", chapterID) }
    func explore(chapterID: String) async -> Bool { await run("explore", chapterID) }

    private func run(_ method: String, _ chapterID: String) async -> Bool {
        guard let script = WebSettingsCommandSink.script(method: method, arguments: [chapterID]) else { return false }
        return await commands().evaluateCommand(script)
    }
}
