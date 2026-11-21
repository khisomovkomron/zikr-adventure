// AppClock.swift
// Источник текущего времени; в тестах подменяется FixedClock.

import Foundation

public protocol AppClock: Sendable {
    var now: Date { get }
}

public struct SystemClock: AppClock {
    public init() {}
    public var now: Date { Date() }
}

public struct FixedClock: AppClock {
    public let now: Date
    public init(_ date: Date) { self.now = date }
}
