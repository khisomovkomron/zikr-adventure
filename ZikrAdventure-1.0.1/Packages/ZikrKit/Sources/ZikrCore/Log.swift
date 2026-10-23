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
    #else
    public static let persistence = PrintLogger(category: "persistence")
    public static let app = PrintLogger(category: "app")
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
