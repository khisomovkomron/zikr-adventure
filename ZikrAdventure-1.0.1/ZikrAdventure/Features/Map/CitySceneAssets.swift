// CitySceneAssets.swift
// ZKR-57: растры сцены города — спрайты объектов, дальний план и земля. Рисует код графики веба
// (MapSpriteFactory: map-draw.js из index.html → Core Graphics); сборка — вне главного потока.

import CoreGraphics
import Foundation
import ZikrContent

struct CitySceneAssets: @unchecked Sendable {
    let cityID: String
    let sprites: [String: MapSprite]
    /// farSprite(el) по индексу city.far.
    let far: [CGImage?]
    let ground: MapGround?
    /// groundKey: открытые главы + предпросмотр (renderGround перерисовывает землю при смене).
    let groundKey: String

    static func groundKey(unlocked: [String], preview: Bool) -> String {
        CityGeometry.unlockKey(unlocked) + (preview ? "P" : "")
    }

    /// Полная сборка (первый показ города) или только земля (новая глава / предпросмотр), если спрайты уже есть.
    static func build(
        cityID: String,
        city: MapContent.City,
        open: [String],
        unlocked: [String],
        preview: Bool,
        reusing previous: CitySceneAssets? = nil
    ) async -> CitySceneAssets? {
        await Task.detached(priority: .userInitiated) {
            guard let factory = try? MapSpriteFactory(open: open) else { return nil }
            let key = groundKey(unlocked: unlocked, preview: preview)
            let ground = factory.ground(city: city, unlocked: unlocked, preview: preview)
            if let previous, previous.cityID == cityID {
                return CitySceneAssets(cityID: cityID, sprites: previous.sprites, far: previous.far, ground: ground, groundKey: key)
            }
            var sprites: [String: MapSprite] = [:]
            for object in city.objects {
                if let sprite = factory.sprite(for: object) { sprites[object.id] = sprite }
            }
            let far = city.far.map { factory.far($0) }
            return CitySceneAssets(cityID: cityID, sprites: sprites, far: far, ground: ground, groundKey: key)
        }.value
    }
}
