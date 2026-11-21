// WebZikrCommandSink.swift
// ZKR-52: команды экрана «Зикр» в веб. Единственный писатель счёта — страница: команда вызывает
// window.zikrNative.tap / undo / reset / clearHistory / explore (index.html), тот выполняет тот же код,
// что веб-экран (zikrTap / zikrUndo / zikrReset → persist() → "save" → progress.json + zikr-state.json),
// и возвращает снимок счётчика JSON-строкой. До загрузки страницы команды ждут в очереди WebViewManager.

import Foundation
import os
import ZikrCore
import ZikrDomain

@MainActor
protocol WebQueryEvaluating: AnyObject {
    /// Выполняет скрипт, когда страница загружена; строка — то, что вернул скрипт (nil — ошибка/null).
    func evaluateQuery(_ script: String) async -> String?
}

@MainActor
final class WebZikrCommandSink: ZikrCommandSink {
    private let queries: () -> any WebQueryEvaluating
    private let commands: () -> any WebCommandEvaluating

    init(
        queries: @escaping () -> any WebQueryEvaluating,
        commands: @escaping () -> any WebCommandEvaluating
    ) {
        self.queries = queries
        self.commands = commands
    }

    func tap() async -> ZikrSnapshot? { await snapshot("tap") }
    func undo() async -> ZikrSnapshot? { await snapshot("undo") }
    func reset(_ mode: ZikrResetMode) async -> ZikrSnapshot? { await snapshot("reset", mode.rawValue) }

    func clearHistory() async -> Bool {
        guard let script = WebSettingsCommandSink.script(method: "clearHistory", arguments: []) else { return false }
        return await commands().evaluateCommand(script)
    }

    func explore(chapterID: String) async -> Bool {
        guard let script = WebSettingsCommandSink.script(method: "explore", arguments: [chapterID]) else { return false }
        return await commands().evaluateCommand(script)
    }

    // MARK: - Скрипт

    private func snapshot(_ method: String, _ arguments: String...) async -> ZikrSnapshot? {
        guard let script = Self.snapshotScript(method: method, arguments: arguments) else { return nil }
        guard let json = await queries().evaluateQuery(script) else {
            Log.zikr.error("zikrNative.\(method, privacy: .public) returned no snapshot")
            return nil
        }
        return Self.decode(json)
    }

    /// `(function(){try{var r=window.zikrNative&&window.zikrNative.m(a);return r?JSON.stringify(r):null;}catch(e){return null;}})()`
    /// — всегда строка или null, без undefined. Аргументы — только JSON от JSONEncoder.
    nonisolated static func snapshotScript(method: String, arguments: [String]) -> String? {
        let encoder = JSONEncoder()
        var encoded: [String] = []
        for argument in arguments {
            guard let data = try? encoder.encode(argument), let json = String(data: data, encoding: .utf8) else { return nil }
            encoded.append(json)
        }
        let call = "window.zikrNative.\(method)(\(encoded.joined(separator: ",")))"
        return "(function(){try{var r=window.zikrNative&&\(call);return r?JSON.stringify(r):null;}catch(e){return null;}})()"
    }

    nonisolated static func decode(_ json: String) -> ZikrSnapshot? {
        try? JSONDecoder().decode(ZikrSnapshot.self, from: Data(json.utf8))
    }
}
