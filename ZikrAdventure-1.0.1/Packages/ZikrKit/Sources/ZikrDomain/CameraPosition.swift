// CameraPosition.swift
// Сохранённое положение камеры карты города (state.cameras[cityId] в index.html).

import Foundation

public struct CameraPosition: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}
