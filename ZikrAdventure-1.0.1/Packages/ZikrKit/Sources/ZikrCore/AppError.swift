// AppError.swift
// Ошибки слоя данных. Сообщения не содержат пользовательских данных.

import Foundation

public enum AppError: Error, Equatable, Sendable {
    case storageRead(String)
    case storageWrite(String)
    case decoding(String)
    case unsupportedSchema(Int)
}
