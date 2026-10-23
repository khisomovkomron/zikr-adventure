// ProgressState.swift
// Состояние прогресса — та же форма, что объект state в index.html (v: 2).
// Ключи JSON ровно: v, total, daily, unlocked, viewed, settings, onboarded, cameras, city, updatedAt.

import Foundation

public struct ProgressState: Codable, Equatable, Sendable {
    public var v: Int
    public var total: Int64
    public var daily: [String: Int64]
    public var unlocked: [String]
    public var viewed: [String]
    public var settings: AppSettings
    public var onboarded: Bool
    public var cameras: [String: CameraPosition]
    public var city: String?
    public var updatedAt: Int64?

    public init(
        v: Int = 2,
        total: Int64 = 0,
        daily: [String: Int64] = [:],
        unlocked: [String] = [],
        viewed: [String] = [],
        settings: AppSettings = AppSettings(),
        onboarded: Bool = false,
        cameras: [String: CameraPosition] = [:],
        city: String? = nil,
        updatedAt: Int64? = nil
    ) {
        self.v = v
        self.total = total
        self.daily = daily
        self.unlocked = unlocked
        self.viewed = viewed
        self.settings = settings
        self.onboarded = onboarded
        self.cameras = cameras
        self.city = city
        self.updatedAt = updatedAt
    }

    /// freshState() из index.html.
    public static func fresh(preferredLanguages: [String]) -> ProgressState {
        ProgressState(settings: .defaults(preferredLanguages: preferredLanguages))
    }

    enum CodingKeys: String, CodingKey {
        case v, total, daily, unlocked, viewed, settings, onboarded, cameras, city, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        v = try c.decode(Int.self, forKey: .v)
        total = try c.decode(Int64.self, forKey: .total)
        daily = try c.decode([String: Int64].self, forKey: .daily)
        unlocked = try c.decode([String].self, forKey: .unlocked)
        viewed = try c.decode([String].self, forKey: .viewed)
        settings = try c.decode(AppSettings.self, forKey: .settings)
        onboarded = try c.decode(Bool.self, forKey: .onboarded)
        cameras = try c.decode([String: CameraPosition].self, forKey: .cameras)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        updatedAt = try c.decodeIfPresent(Int64.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(v, forKey: .v)
        try c.encode(total, forKey: .total)
        try c.encode(daily, forKey: .daily)
        try c.encode(unlocked, forKey: .unlocked)
        try c.encode(viewed, forKey: .viewed)
        try c.encode(settings, forKey: .settings)
        try c.encode(onboarded, forKey: .onboarded)
        try c.encode(cameras, forKey: .cameras)
        // city и updatedAt пишутся всегда (null, если нет), чтобы набор ключей был стабильным.
        try c.encode(city, forKey: .city)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}
