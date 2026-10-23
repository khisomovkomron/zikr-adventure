// ChapterCatalog.swift
// Пороги глав из CHAPTERS в index.html (id и n). Используется sanitize() для фильтра unlocked.

import Foundation

public enum ChapterCatalog {
    public static let thresholds: [(id: String, n: Int64)] = [
        ("ch01", 10),
        ("ch02", 25),
        ("ch03", 50),
        ("ch04", 100),
        ("ch05", 250),
        ("ch06", 500),
        ("ch07", 1_000),
        ("ch08", 2_500),
        ("ch09", 5_000),
        ("ch10", 10_000),
        ("ch11", 25_000),
        ("ch12", 50_000),
        ("ch13", 100_000),
        ("ch14", 250_000),
        ("ch15", 500_000),
        ("ch16", 1_000_000),
        ("ch17", 5_000_000),
        ("ch18", 10_000_000),
        ("ch19", 100_000_000),
    ]

    public static let ids: Set<String> = Set(thresholds.map { $0.id })
}
