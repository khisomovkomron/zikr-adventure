// WebMapCommandSink.swift
// ZKR-57: команды экрана «Карта» в веб. Единственный писатель city / cameras / viewed — страница:
// window.zikrNative.selectCity / saveCamera / markViewed (index.html) повторяют selectWorldCity, saveCam
// и markViewed веб-карты и сохраняют состояние (persist() → "save" → progress.json + zikr-state.json).
// До загрузки страницы команды ждут в очереди WebViewManager.

import Foundation
import ZikrDomain

@MainActor
final class WebMapCommandSink: MapCommandSink {
    private let commands: () -> any WebCommandEvaluating

    init(commands: @escaping () -> any WebCommandEvaluating) {
        self.commands = commands
    }

    func selectCity(_ cityID: String?) async -> Bool { await run("selectCity", [cityID]) }

    func saveCamera(cityID: String, x: Double, y: Double, z: Double) async -> Bool {
        guard [x, y, z].allSatisfy(\.isFinite) else { return false }
        return await run("saveCamera", [cityID, x, y, z])
    }

    func markViewed(chapterID: String) async -> Bool { await run("markViewed", [chapterID]) }

    private func run(_ method: String, _ arguments: [any Encodable]) async -> Bool {
        guard let script = WebSettingsCommandSink.script(method: method, arguments: arguments) else { return false }
        return await commands().evaluateCommand(script)
    }
}
