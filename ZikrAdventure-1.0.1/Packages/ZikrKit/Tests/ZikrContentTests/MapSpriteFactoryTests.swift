// ZKR-57: спрайты карты из кода графики веба (map-draw.js) через JavaScriptCore + Core Graphics.
#if canImport(JavaScriptCore) && canImport(CoreGraphics)
import CoreGraphics
import XCTest
@testable import ZikrContent

final class MapSpriteFactoryTests: XCTestCase {
    private var content: MapContent!

    override func setUpWithError() throws {
        content = try BundledMapContentProvider().loadMapContent()
    }

    func testSpritesMatchGeometryFramesForEveryObject() throws {
        let factory = try MapSpriteFactory(open: [])
        for id in MapContent.cityIDs {
            let city = try XCTUnwrap(content.cities[id])
            for object in city.objects {
                let sprite = factory.sprite(for: object)
                guard let frame = CityGeometry.spriteFrame(object) else {
                    XCTAssertNil(sprite, "\(id)/\(object.id): hotspot без спрайта")
                    continue
                }
                let s = try XCTUnwrap(sprite, "\(id)/\(object.id)")
                XCTAssertEqual(s.frame, frame, "\(id)/\(object.id): рамка drawObject = CityGeometry.spriteFrame")
                // mkCanvas: ceil(W · DPR 2) × ceil(H · 2).
                XCTAssertEqual(s.image.width, Int((frame.width * 2).rounded(.up)), object.id)
                XCTAssertEqual(s.image.height, Int((frame.height * 2).rounded(.up)), object.id)
            }
        }
    }

    func testKaabaSpriteHasDarkCoverAndTransparentCorners() throws {
        let factory = try MapSpriteFactory(open: [])
        let kaaba = try XCTUnwrap(content.cities["mecca"]?.object(id: "kaaba"))
        let sprite = try XCTUnwrap(factory.sprite(for: kaaba))
        let pixels = try Pixels(sprite.image)
        XCTAssertEqual(pixels.alpha(x: 0, y: 0), 0, "угол холста прозрачный")
        // Центр верхней грани покрывала (#2A2A30 × 1.08) — тёмный и непрозрачный.
        let top = pixels.rgba(x: sprite.image.width / 2, y: Int((sprite.frame.anchorY - Double(kaaba.h) - 2) * 2))
        XCTAssertEqual(top[3], 255)
        XCTAssertLessThan(top[0], 80)
    }

    func testGroundTilesAndRouteOverlay() throws {
        let mecca = try XCTUnwrap(content.cities["mecca"])
        let closed = try XCTUnwrap(try MapSpriteFactory(open: []).ground(city: mecca, unlocked: [], preview: false))
        XCTAssertEqual([closed.width, closed.height, closed.originX], [2560, 1280, 1280])
        XCTAssertEqual(closed.image.width, 3840, "renderGround: масштаб min(DPR, 1.5)")
        let pixels = try Pixels(closed.image)
        // Центр тайла (x, y) = iso(x + .5, y + .5) + ox; цвет — shadeHex(fill, [1, .97, 1.03][variant]).
        let (gx, gy) = (3, 30)
        let type = mecca.terrain[gy][gx]
        let fill = try XCTUnwrap(content.terrainTypes[type]).fill
        let f = [1, 0.97, 1.03][CityGeometry.tileVariant(gx, gy)]
        let expected = try XCTUnwrap(CanvasColor.components(fill)).prefix(3).map { min(255, ($0 * 255 * f).rounded()) }
        let center = CityGeometry.iso(Double(gx) + 0.5, Double(gy) + 0.5)
        let px = pixels.rgba(x: Int((center.x + closed.originX) * 1.5), y: Int(center.y * 1.5))
        for i in 0..<3 { XCTAssertEqual(Double(px[i]), expected[i], accuracy: 30, "канал \(i) тайла \(type)") }
        XCTAssertEqual(px[3], 255)
    }

    func testFarSpriteFadesToTransparentAtBottom() throws {
        let factory = try MapSpriteFactory(open: [])
        let far = try XCTUnwrap(content.cities["mecca"]?.far.first)
        let image = try XCTUnwrap(factory.far(far))
        let pixels = try Pixels(image)
        XCTAssertEqual(image.width, Int((far.w * 2).rounded(.up)))
        XCTAssertEqual(pixels.alpha(x: image.width / 2, y: image.height - 1), 0, "destination-in: низ прозрачный")
    }

    func testCanvasColors() {
        XCTAssertEqual(CanvasColor.components("#fff"), [1, 1, 1, 1])
        XCTAssertEqual(CanvasColor.components("#C2A05A33")?.last.map { ($0 * 255).rounded() }, 0x33)
        XCTAssertEqual(CanvasColor.components("rgba(0,0,0,.26)")?.last, 0.26)
        XCTAssertNil(CanvasColor.components("var(--x)"))
    }
}

/// RGBA8 копия CGImage для проверок пикселей (сверху вниз).
private struct Pixels {
    let width: Int
    let bytes: [UInt8]

    init(_ image: CGImage) throws {
        width = image.width
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let ok = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(ok)
        bytes = data
    }

    func rgba(x: Int, y: Int) -> [UInt8] {
        let i = (y * width + x) * 4
        return Array(bytes[i..<i + 4])
    }

    func alpha(x: Int, y: Int) -> UInt8 { rgba(x: x, y: y)[3] }
}
#endif
