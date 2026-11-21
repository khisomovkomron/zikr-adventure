// MapCommands.swift
// ZKR-57: команды экрана «Карта» в веб (window.zikrNative.*). Веб — единственный писатель city / cameras / viewed.

import Foundation

public protocol MapCommandSink: Sendable {
    /// selectWorldCity(c): выбранный город обзорной карты (state.city), nil — снять выбор.
    @discardableResult func selectCity(_ cityID: String?) async -> Bool
    /// saveCam(city): камера города после жеста или анимации (state.cameras[id]).
    @discardableResult func saveCamera(cityID: String, x: Double, y: Double, z: Double) async -> Bool
    /// placeCard() / explore(): отметить открытую главу просмотренной (тот же markViewed, что у «Пути Сиры»).
    @discardableResult func markViewed(chapterID: String) async -> Bool
}
