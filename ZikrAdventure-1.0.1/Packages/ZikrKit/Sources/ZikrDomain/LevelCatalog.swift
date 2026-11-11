// LevelCatalog.swift
// ZKR-52: границы 7 уровней из LEVELS в index.html (from/to). Названия на 6 языках —
// ZikrContent/zikr-content.json (tools/zikr-content-from-web.mjs).

import Foundation

public enum LevelCatalog {
    public struct Bounds: Equatable, Sendable {
        public let from: Int64
        public let to: Int64

        public init(from: Int64, to: Int64) {
            self.from = from
            self.to = to
        }
    }

    public static let levels: [Bounds] = [
        Bounds(from: 0, to: 100),
        Bounds(from: 100, to: 1_000),
        Bounds(from: 1_000, to: 10_000),
        Bounds(from: 10_000, to: 100_000),
        Bounds(from: 100_000, to: 1_000_000),
        Bounds(from: 1_000_000, to: 10_000_000),
        Bounds(from: 10_000_000, to: 100_000_000),
    ]
}
