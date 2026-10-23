// LegacySources.swift
// Исходные данные для первичной миграции и результат bootstrap.

import Foundation

/// Исходные данные для первичной миграции (все поля — сырые JSON-строки).
public struct LegacySources: Equatable, Sendable {
    /// Содержимое Application Support/progress.json (нативная копия веб-состояния).
    public var progressFileJSON: String?
    /// JSON.stringify(state) живой страницы.
    public var webLiveJSON: String?
    /// localStorage["zikr-adventure.v2"].
    public var localStorageV2: String?
    /// localStorage["zikr-adventure.v1"].
    public var localStorageV1: String?

    public init(
        progressFileJSON: String? = nil,
        webLiveJSON: String? = nil,
        localStorageV2: String? = nil,
        localStorageV1: String? = nil
    ) {
        self.progressFileJSON = progressFileJSON
        self.webLiveJSON = webLiveJSON
        self.localStorageV2 = localStorageV2
        self.localStorageV1 = localStorageV1
    }

    /// Только progress.json. Отсутствующий или нечитаемый файл → progressFileJSON == nil.
    /// Файл только читается.
    public static func progressFile(at url: URL) -> LegacySources {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            return LegacySources()
        }
        return LegacySources(progressFileJSON: text)
    }
}

public enum BootstrapResult: Equatable, Sendable {
    /// zikr-state.json уже был (schemaVersion == 3); файл не переписывался.
    case existing
    /// Файл создан из указанного источника.
    case created(from: String)
    /// Источников нет — файл не создаётся.
    case empty
    /// Файл из будущей версии схемы; запись отключена на эту сессию.
    case readOnly(reason: String)
    /// ZKR-61: файл есть, но сейчас не читается (ошибка ввода-вывода). Файл не изменялся;
    /// чтение повторится при следующем обращении к хранилищу.
    case unavailable(reason: String)
}

