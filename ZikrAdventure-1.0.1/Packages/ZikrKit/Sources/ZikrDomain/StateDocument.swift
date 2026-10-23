// StateDocument.swift
// Файл zikr-state.json: версия схемы, прогресс и служебные метаданные.

import Foundation

public struct StateDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 3

    public struct Meta: Codable, Equatable, Sendable {
        public var createdAt: Date
        /// progressFile | webLive | localStorageV2 | localStorageV1 | fresh
        public var createdFrom: String
        public var lastWebSyncAt: Date?
        public var writtenByAppVersion: String

        public init(createdAt: Date, createdFrom: String, lastWebSyncAt: Date? = nil, writtenByAppVersion: String) {
            self.createdAt = createdAt
            self.createdFrom = createdFrom
            self.lastWebSyncAt = lastWebSyncAt
            self.writtenByAppVersion = writtenByAppVersion
        }
    }

    public var schemaVersion: Int
    public var progress: ProgressState
    public var meta: Meta

    public init(schemaVersion: Int = StateDocument.currentSchemaVersion, progress: ProgressState, meta: Meta) {
        self.schemaVersion = schemaVersion
        self.progress = progress
        self.meta = meta
    }
}
