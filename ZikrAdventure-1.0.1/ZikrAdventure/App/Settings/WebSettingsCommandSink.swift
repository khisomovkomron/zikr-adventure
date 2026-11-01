// WebSettingsCommandSink.swift
// ZKR-50: запись настроек из нативного экрана. Единственный писатель — веб: команда вызывает
// window.zikrNative.* (index.html), а тот выполняет тот же код, что веб-экран «Настройки»
// (state.settings → persist() → localStorage + "save" → progress.json + zikr-state.json).
// Аргументы — только JSON от JSONEncoder; до загрузки страницы команды ждут в очереди WebViewManager.

import Foundation
import os
import ZikrCore
import ZikrDomain

@MainActor
protocol WebCommandEvaluating: AnyObject {
    /// Выполняет скрипт, когда страница загружена; true — скрипт вернул true.
    func evaluateCommand(_ script: String) async -> Bool
}

@MainActor
final class WebSettingsCommandSink: SettingsCommandSink {
    private let evaluator: () -> any WebCommandEvaluating

    init(evaluator: @escaping () -> any WebCommandEvaluating) {
        self.evaluator = evaluator
    }

    func set(_ field: SettingsField) async -> Bool {
        switch field {
        case .toggle(_, let value):
            return await call("setSetting", field.key, value)
        case .goal(let value):
            return await call("setSetting", field.key, value)
        }
    }

    func setLanguage(_ language: AppLanguage) async -> Bool {
        await call("setLang", language.rawValue)
    }

    func resetDefaults() async -> Bool { await call("resetDefaults") }
    func clearHistory() async -> Bool { await call("clearHistory") }
    func resetProgress() async -> Bool { await call("resetProgress") }

    // MARK: - Скрипт

    private func call(_ method: String, _ arguments: any Encodable...) async -> Bool {
        guard let script = Self.script(method: method, arguments: arguments) else { return false }
        let ok = await evaluator().evaluateCommand(script)
        if !ok {
            Log.settings.error("zikrNative.\(method, privacy: .public) returned false")
        }
        return ok
    }

    /// `(function(){try{return !!(window.zikrNative && window.zikrNative.m(a,b));}catch(e){return false;}})()`
    /// — всегда Bool, чтобы evaluateJavaScript не получал undefined.
    nonisolated static func script(method: String, arguments: [any Encodable]) -> String? {
        let encoder = JSONEncoder()
        var encoded: [String] = []
        for argument in arguments {
            guard let data = try? encoder.encode(AnyEncodable(argument)),
                  let json = String(data: data, encoding: .utf8) else { return nil }
            encoded.append(json)
        }
        let call = "window.zikrNative.\(method)(\(encoded.joined(separator: ",")))"
        return "(function(){try{return !!(window.zikrNative && \(call));}catch(e){return false;}})()"
    }
}

private struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
