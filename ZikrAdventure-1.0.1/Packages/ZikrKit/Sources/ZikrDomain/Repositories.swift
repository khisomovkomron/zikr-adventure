// Repositories.swift
// Контракты доступа к данным для нативных экранов (ZKR-49; changes() настроек — ZKR-50).

import Foundation

/// Хранилище документа состояния (реализация — JSONStateStore в ZikrPersistence).
public protocol StateStore: Sendable {
    func document() async -> StateDocument?
    @discardableResult
    func update(_ mutate: @Sendable (inout ProgressState) -> Void) async throws -> ProgressState
    func changes() async -> AsyncStream<ProgressState>
}

public protocol ProgressRepository: Sendable {
    func load() async -> ProgressState?
    @discardableResult
    func update(_ mutate: @Sendable (inout ProgressState) -> Void) async throws -> ProgressState
    func changes() async -> AsyncStream<ProgressState>
}

public protocol SettingsRepository: Sendable {
    func load() async -> AppSettings?
    @discardableResult
    func update(_ mutate: @Sendable (inout AppSettings) -> Void) async throws -> AppSettings
    /// ZKR-50: настройки после каждой записи zikr-state.json (только при изменении настроек).
    func changes() async -> AsyncStream<AppSettings>
}
