// MapContent.swift
// ZKR-57: сцена экрана «Карта» — раскладка карт Мекки и Медины (makeCity), порядок отрисовки (buildCity),
// местность, наложения (улицы и слои глав), дальний план, палитра TERRAIN и GEO обзорной карты.
// map-content.json генерируется из index.html (node tools/zikr-map-from-web.mjs), руками не правится.

import Foundation
import ZikrCore

public struct MapContent: Codable, Equatable, Sendable {
    /// Объект карты города (элемент city.objects после buildCity()).
    public struct Object: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        /// kaaba, mosqueNabawi, house, palm, camel, hotspot, … — как o.kind в drawObject().
        public let kind: String
        /// Ключ места (PLACES): у мест — маркер «i» и карточка placeCard().
        public let place: String?
        /// Сафа (0) / Марва (1) у места safamarwa.
        public let sub: Int?
        public let x: Int
        public let y: Int
        public let w: Int
        public let d: Int
        public let h: Double
        public let v: Int
        /// Глава, с которой объект появляется на карте (visible()).
        public let layer: String?
        /// Ключ названия объекта (obj.*) для objectCard().
        public let name: String?
        public let cat: String?
        public let interactive: Bool?
        /// "sway" (пальмы), "glow" (фонари), "none".
        public let anim: String?
        public let markAt: [Double]?
        public let markH: Double?
        /// Глава места (chapterOfPlace).
        public let chapter: String?
        public let depth: Double
        public let shadow: Bool

        public var isInteractive: Bool { interactive ?? false }

        public init(
            id: String, kind: String, place: String? = nil, sub: Int? = nil,
            x: Int, y: Int, w: Int = 1, d: Int = 1, h: Double, v: Int = 0,
            layer: String? = nil, name: String? = nil, cat: String? = nil, interactive: Bool? = nil,
            anim: String? = nil, markAt: [Double]? = nil, markH: Double? = nil, chapter: String? = nil,
            depth: Double = 0, shadow: Bool = true
        ) {
            self.id = id; self.kind = kind; self.place = place; self.sub = sub
            self.x = x; self.y = y; self.w = w; self.d = d; self.h = h; self.v = v
            self.layer = layer; self.name = name; self.cat = cat; self.interactive = interactive
            self.anim = anim; self.markAt = markAt; self.markH = markH; self.chapter = chapter
            self.depth = depth; self.shadow = shadow
        }
    }

    /// Наложение на землю: street, market, path, route, wadi, trench (drawOverlay()).
    public struct Overlay: Codable, Equatable, Sendable {
        public let type: String
        public let pts: [[Double]]
        public let layer: String?
    }

    /// Дальний план (farSprite): горы или холмы за картой.
    public struct Far: Codable, Equatable, Sendable {
        public let id: String
        public let off: Double
        public let w: Double
        public let h: Double
        public let depth: Double
        public let v: Int
        public let hills: Bool
    }

    public struct City: Codable, Equatable, Sendable {
        public let focus: [Double]
        public let base: String
        /// Уже по порядку отрисовки (глубине).
        public let objects: [Object]
        public let overlays: [Overlay]
        /// terrain[y][x] — ключ TERRAIN.
        public let terrain: [[String]]
        public let far: [Far]

        public func object(id: String) -> Object? { objects.first { $0.id == id } }
    }

    public struct Terrain: Codable, Equatable, Sendable {
        public let fill: String
        public let detail: String
        public let count: Int
    }

    public struct GeoCity: Codable, Equatable, Sendable {
        public let lon: Double
        public let lat: Double
        public let ar: String
    }

    /// GEO обзорной карты: контуры [lon, lat].
    public struct Geo: Codable, Equatable, Sendable {
        public let peninsula: [[Double]]
        public let saudi: [[Double]]
        public let africa: [[Double]]
        public let sinai: [[Double]]
        public let mountains: [[Double]]
        public let cities: [String: GeoCity]
    }

    public let size: Int
    public let terrainTypes: [String: Terrain]
    public let cities: [String: City]
    public let geo: Geo

    public static let cityIDs = ["mecca", "medina"]

    public static func decode(from data: Data) throws -> MapContent {
        try JSONDecoder().decode(MapContent.self, from: data)
    }
}

public protocol MapContentProviding: Sendable {
    func loadMapContent() throws -> MapContent
}

/// map-content.json из ресурсов модуля ZikrContent.
public struct BundledMapContentProvider: MapContentProviding {
    public static let resourceName = "map-content"
    private let url: URL?

    public init() {
        self.url = Bundle.module.url(forResource: Self.resourceName, withExtension: "json")
    }

    public init(url: URL) {
        self.url = url
    }

    public func loadMapContent() throws -> MapContent {
        guard let url, let data = try? Data(contentsOf: url) else {
            throw AppError.storageRead("map-content.json")
        }
        return try MapContent.decode(from: data)
    }
}
