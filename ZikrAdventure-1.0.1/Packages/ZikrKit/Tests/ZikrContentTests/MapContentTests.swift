// MapContentTests.swift
// ZKR-57: map-content.json (сцены карт из index.html) и CityGeometry — 1:1 с функциями веба.

import XCTest
@testable import ZikrContent

final class MapContentTests: XCTestCase {
    private func content() throws -> MapContent {
        try BundledMapContentProvider().loadMapContent()
    }

    func testBundledContentHasBothCities() throws {
        let map = try content()
        XCTAssertEqual(map.size, 40)
        XCTAssertEqual(map.cities["mecca"]?.objects.count, 84)
        XCTAssertEqual(map.cities["medina"]?.objects.count, 109)
        XCTAssertEqual(map.cities["mecca"]?.base, "kaaba")
        XCTAssertEqual(map.cities["medina"]?.base, "nabawi")
        for id in MapContent.cityIDs {
            let city = try XCTUnwrap(map.cities[id])
            XCTAssertEqual(city.terrain.count, 40)
            XCTAssertTrue(city.terrain.allSatisfy { $0.count == 40 })
            XCTAssertTrue(city.terrain.joined().allSatisfy { map.terrainTypes[$0] != nil }, id)
        }
        XCTAssertEqual(map.cities["mecca"]?.terrain[20][20], "courtyard")
        XCTAssertEqual(map.cities["mecca"]?.terrain[0][0], "rock")
        XCTAssertEqual(map.cities["medina"]?.terrain[20][20], "urban")
        XCTAssertEqual(map.geo.cities["mecca"]?.ar, "مكة المكرمة")
    }

    func testPlacesAndChaptersMatchWeb() throws {
        let map = try content()
        let mecca = try XCTUnwrap(map.cities["mecca"]).objects.filter { $0.place != nil }.map { "\($0.id):\($0.chapter ?? "-")" }
        XCTAssertEqual(mecca, ["nur:ch05", "khadija:ch03", "marwa:ch06", "maqam:ch17", "blackstone:ch04", "kaaba:ch16", "zamzam:ch02", "arqam:ch07", "safa:ch06", "thawr:ch08"])
        let medina = try XCTUnwrap(map.cities["medina"]).objects.filter { $0.place != nil }.map { "\($0.id):\($0.chapter ?? "-")" }
        XCTAssertEqual(medina, ["uhud:ch14", "qiblatayn:ch12", "fath:ch15", "nabawi:ch11", "baqi:ch13", "jumua:ch10", "quba:ch09"])
    }

    func testObjectsAreInDrawOrder() throws {
        let map = try content()
        for id in MapContent.cityIDs {
            let depths = try XCTUnwrap(map.cities[id]).objects.map(\.depth)
            XCTAssertEqual(depths, depths.sorted(), id)
        }
    }

    func testNoiseAndTileVariantMatchJavaScript() {
        // Значения посчитаны node для noise() и tileVariant() из index.html.
        XCTAssertEqual(CityGeometry.noise(7, 1), 0.764, accuracy: 1e-9)
        XCTAssertEqual(CityGeometry.noise(13, 600), 0.297, accuracy: 1e-9)
        XCTAssertEqual(CityGeometry.noise(2345, 77), 0.898, accuracy: 1e-9)
        XCTAssertEqual(CityGeometry.noise(0, 0), 0)
        XCTAssertEqual(CityGeometry.tileVariant(39, 39), 1)
        XCTAssertEqual(CityGeometry.tileVariant(17, 23), 0)
        XCTAssertEqual(CityGeometry.tileVariant(1, 30), 2)
    }

    func testClampCamera() {
        let c = CityGeometry.clamp(.init(x: .nan, y: 10_000, z: 99), size: 40)
        XCTAssertEqual(c, .init(x: 0, y: 40 * 2 * 16 + 40, z: 1 / 0.45))
        let d = CityGeometry.clamp(.init(x: -10_000, y: -10_000, z: 0.01), size: 40)
        XCTAssertEqual(d, .init(x: -40 * 32 - 40, y: -160, z: 1 / 2.6))
        XCTAssertEqual(CityGeometry.clamp(.init(x: 1, y: 2, z: .infinity), size: 40).z, 1)
    }

    func testScreenSceneRoundTrip() {
        let cam = CityGeometry.Camera(x: 120, y: 640, z: 1.4)
        let view = CityGeometry.Size(width: 390, height: 700)
        let scene = CityGeometry.Point(33, -12)
        let back = CityGeometry.toScene(cam, view: view, CityGeometry.toScreen(cam, view: view, scene))
        XCTAssertEqual(back.x, scene.x, accuracy: 1e-9)
        XCTAssertEqual(back.y, scene.y, accuracy: 1e-9)
    }

    func testHitTestPrefersPlaceMarkerAndRespectsLayers() throws {
        let city = try XCTUnwrap(content().cities["mecca"])
        let kaaba = try XCTUnwrap(city.object(id: "kaaba"))
        let cam = CityGeometry.Camera(x: 0, y: 600, z: 1)
        let view = CityGeometry.Size(width: 390, height: 700)
        let marker = CityGeometry.toScreen(cam, view: view, CityGeometry.markerPosition(kaaba))
        let hit = CityGeometry.hitTest(objects: city.objects, camera: cam, view: view, at: marker, isOpen: { _ in false })
        XCTAssertEqual(hit?.id, "kaaba")
        // Верблюд слоя ch01 не находится, пока глава закрыта.
        let camel = try XCTUnwrap(city.objects.first { $0.kind == "camel" })
        let at = CityGeometry.toScreen(cam, view: view, CityGeometry.center(camel))
        XCTAssertNotEqual(CityGeometry.hitTest(objects: city.objects, camera: cam, view: view, at: at, isOpen: { _ in false })?.id, camel.id)
        XCTAssertEqual(CityGeometry.hitTest(objects: city.objects, camera: cam, view: view, at: at, isOpen: { _ in true })?.id, camel.id)
    }

    func testMarkerAndFocus() throws {
        let city = try XCTUnwrap(content().cities["mecca"])
        let blackstone = try XCTUnwrap(city.object(id: "blackstone"))
        XCTAssertEqual(CityGeometry.markerPosition(blackstone), CityGeometry.Point((21 - 19) * 32, (21 + 19) * 16 - 10 - 22))
        XCTAssertNil(CityGeometry.spriteFrame(blackstone))
        let kaaba = try XCTUnwrap(city.object(id: "kaaba"))
        XCTAssertEqual(CityGeometry.focusTarget(kaaba, currentZoom: 0.5), .init(x: 0, y: 20 * 32 - 40, z: 1))
        XCTAssertEqual(CityGeometry.home(city), .init(x: 0, y: 640, z: 1))
        let intro = CityGeometry.initialCamera(saved: nil, city: city, size: 40)
        XCTAssertTrue(intro.animatesIntro)
        XCTAssertEqual(intro.camera.z, 1 / 1.8, accuracy: 1e-12)
        XCTAssertFalse(CityGeometry.initialCamera(saved: .init(x: 1, y: 2, z: 3), city: city, size: 40).animatesIntro)
    }

    func testWorldViewBox() throws {
        let map = try content()
        XCTAssertEqual(WorldGeometry.viewBox(city: nil), [-440, -420, 800, 740])
        let mecca = try XCTUnwrap(map.geo.cities["mecca"])
        let p = WorldGeometry.project(lon: mecca.lon, lat: mecca.lat)
        XCTAssertEqual(WorldGeometry.viewBox(city: mecca), [p.x - 170, p.y - 150, 340, 400])
        XCTAssertEqual(CityGeometry.ease(0.5), 0.5, accuracy: 1e-12)
    }
}
