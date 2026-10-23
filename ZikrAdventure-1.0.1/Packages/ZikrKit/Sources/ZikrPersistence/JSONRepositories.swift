// JSONRepositories.swift
// Репозитории поверх StateStore для будущих нативных экранов.

import Foundation
import ZikrDomain

public struct JSONProgressRepository: ProgressRepository {
    private let store: any StateStore

    public init(store: any StateStore) {
        self.store = store
    }

    public func load() async -> ProgressState? {
        await store.document()?.progress
    }

    @discardableResult
    public func update(_ mutate: @Sendable (inout ProgressState) -> Void) async throws -> ProgressState {
        try await store.update(mutate)
    }

    public func changes() async -> AsyncStream<ProgressState> {
        await store.changes()
    }
}

public struct JSONSettingsRepository: SettingsRepository {
    private let store: any StateStore

    public init(store: any StateStore) {
        self.store = store
    }

    public func load() async -> AppSettings? {
        await store.document()?.progress.settings
    }

    @discardableResult
    public func update(_ mutate: @Sendable (inout AppSettings) -> Void) async throws -> AppSettings {
        try await store.update { progress in mutate(&progress.settings) }.settings
    }
}
