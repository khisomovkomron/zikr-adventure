// CitySceneAssets.swift
// ZKR-57: растры сцены города — спрайты объектов, дальний план и земля. Рисует код графики веба
// (MapSpriteFactory: map-draw.js из index.html → Core Graphics); сборка — вне главного потока.

import CoreGraphics
import Foundation
import ZikrContent

/// Один MapSpriteFactory (один JSContext с map-draw.js и кэшем тайлов) на всё приложение: пересборка земли при новой
/// главе или предпросмотре не создаёт контекст заново. Фабрика не потокобезопасна — доступ под замком.
private final class SpriteFactoryPool: @unchecked Sendable {
    private let lock = NSLock()
    private var factory: MapSpriteFactory?
    private var created = 0
    var creations: Int { lock.lock(); defer { lock.unlock() }; return created }

    func perform<T>(open: [String], _ body: (MapSpriteFactory) -> T?) -> T? {
        lock.lock()
        defer { lock.unlock() }
        if factory == nil {
            factory = try? MapSpriteFactory(open: open)
            if factory != nil { created += 1 }
        }
        guard let factory else { return nil }
        factory.setOpen(open)
        defer { factory.purgeImageCache() }
        return body(factory)
    }
}

struct CitySceneAssets: @unchecked Sendable {
    let cityID: String
    let sprites: [String: MapSprite]
    /// farSprite(el) по индексу city.far.
    let far: [CGImage?]
    let ground: MapGround?
    /// groundKey: открытые главы + предпросмотр (renderGround перерисовывает землю при смене).
    let groundKey: String

    private static let factories = SpriteFactoryPool()

    /// Сколько раз создавался JSContext (тесты: один на приложение).
    static var factoryCreations: Int { factories.creations }

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
            factories.perform(open: open) { factory -> CitySceneAssets? in
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
            }
        }.value
    }
}
