// Log.swift
// Логирование слоя данных. В лог пишутся только технические сведения
// (тип ошибки, версия схемы), без содержимого прогресса пользователя.

import Foundation
#if canImport(os)
import os
#endif

public enum Log {
    public static let subsystem = "com.komronkhisomov.zikradventure"

    #if canImport(os)
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")
    public static let app = Logger(subsystem: subsystem, category: "app")
    /// ZKR-50: экран «Настройки» (команды в веб, синхронизация).
    public static let settings = Logger(subsystem: subsystem, category: "settings")
    /// ZKR-50: вход и удаление аккаунта — только domain/code ошибок, без токенов, email и uid.
    public static let auth = Logger(subsystem: subsystem, category: "auth")
    #else
    public static let persistence = PrintLogger(category: "persistence")
    public static let app = PrintLogger(category: "app")
    public static let settings = PrintLogger(category: "settings")
    public static let auth = PrintLogger(category: "auth")
    #endif
}

#if !canImport(os)
/// Минимальная замена os.Logger для платформ без os (например Linux CI).
public struct PrintLogger: Sendable {
    let category: String
    public func error(_ message: String) { print("[\(category)] error: \(message)") }
    public func info(_ message: String) { print("[\(category)] info: \(message)") }
    public func debug(_ message: String) {}
}
#endif
