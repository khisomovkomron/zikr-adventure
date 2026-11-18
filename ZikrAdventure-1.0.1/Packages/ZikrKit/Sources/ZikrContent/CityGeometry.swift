// CityGeometry.swift
// ZKR-57: чистая геометрия карты города — порт 1:1 iso(), clampCam(), toScreen()/toScene(), objCenter(),
// markerPos(), visible(), hitTest(), focusObject(), tileVariant() и noise() из index.html. Без UI:
// отрисовка (CityRenderer) и жесты (CityCanvasView) только подставляют эти числа.

import Foundation

public enum CityGeometry {
    /// Полуширина и полувысота ромба клетки (HW, HH).
    public static let halfWidth: Double = 32
    public static let halfHeight: Double = 16
    /// Пределы масштаба (ZMIN, ZMAX).
    public static let minZoom: Double = 1 / 2.6
    public static let maxZoom: Double = 1 / 0.45
    /// Начальный масштаб «наезда» при первом открытии города (1 / 1.8 → 1 за 1100 мс).
    public static let introZoom: Double = 1 / 1.8
    public static let introDuration: Double = 1.1
    /// Подписи мест видны при c.z > 0.75.
    public static let labelZoom: Double = 0.75

    /// Камера города: центр сцены (x, y) и масштаб z.
    public struct Camera: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var z: Double

        public init(x: Double, y: Double, z: Double) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double

        public init(_ x: Double, _ y: Double) {
            self.x = x
            self.y = y
        }
    }

    public struct Size: Equatable, Sendable {
        public var width: Double
        public var height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }

    /// iso(gx, gy).
    public static func iso(_ gx: Double, _ gy: Double) -> Point {
        Point((gx - gy) * halfWidth, (gx + gy) * halfHeight)
    }

    /// clampCam(): нечисловые значения → z 1, x/y 0; затем пределы сцены SIZE.
    public static func clamp(_ camera: Camera, size: Int) -> Camera {
        let s = Double(size)
        let z = camera.z.isFinite ? camera.z : 1
        let x = camera.x.isFinite ? camera.x : 0
        let y = camera.y.isFinite ? camera.y : 0
        return Camera(
            x: min(s * halfWidth + 40, max(-s * halfWidth - 40, x)),
            y: min(s * 2 * halfHeight + 40, max(-160, y)),
            z: min(maxZoom, max(minZoom, z))
        )
    }

    public static func toScreen(_ camera: Camera, view: Size, _ scene: Point) -> Point {
        Point((scene.x - camera.x) * camera.z + view.width / 2, (scene.y - camera.y) * camera.z + view.height / 2)
    }

    public static func toScene(_ camera: Camera, view: Size, _ screen: Point) -> Point {
        Point((screen.x - view.width / 2) / camera.z + camera.x, (screen.y - view.height / 2) / camera.z + camera.y)
    }

    /// objCenter(o).
    public static func center(_ o: MapContent.Object) -> Point {
        iso(Double(o.x) + Double(o.w) / 2, Double(o.y) + Double(o.d) / 2)
    }

    /// markerPos(o): точка маркера «i» над объектом.
    public static func markerPosition(_ o: MapContent.Object) -> Point {
        if let at = o.markAt, at.count == 2 {
            let p = iso(at[0], at[1])
            return Point(p.x, p.y - (o.markH ?? 0) - 22)
        }
        let c = center(o)
        let lift = o.kind == "uhudRidge" || o.kind == "caveMountain" ? o.h * 0.8 : o.h
        return Point(c.x, c.y - lift - 22)
    }

    /// visible(o): без слоя или слой главы открыт (isOpen с предпросмотром).
    public static func isVisible(_ o: MapContent.Object, isOpen: (String) -> Bool) -> Bool {
        o.layer.map(isOpen) ?? true
    }

    /// Верх холста спрайта (`tall` в drawObject): высота над ромбом основания.
    public static func spriteTop(_ o: MapContent.Object) -> Double {
        switch o.kind {
        case "kaaba": return 40
        case "mosqueNabawi": return 34
        case "quba": return 30
        case "qiblatayn": return 34
        case "arqam": return 42
        case "khadija": return 32
        case "house": return 30
        case "caveMountain", "uhudRidge": return o.h + 10
        case "fathHill": return o.h + 28
        case "rockHill", "mountain", "hill": return o.h + 8
        case "palm", "palmGrove": return 48
        case "tent": return 26
        case "camel": return 30
        case "stall": return 26
        case "lantern": return 34
        case "well": return 30
        case "trough": return 14
        case "bush": return 16
        case "graves": return 12
        case "maqam", "zamzam": return 22
        case "jumua": return 12
        case "baqi": return 14
        case "basalt": return o.h + 6
        default: return o.h + 10
        }
    }

    /// Рамка спрайта: размер холста (W, H) и якорь (ax, ay) относительно objCenter. nil — hotspot (без спрайта).
    public struct SpriteFrame: Equatable, Sendable {
        public let width: Double
        public let height: Double
        public let anchorX: Double
        public let anchorY: Double
    }

    public static func spriteFrame(_ o: MapContent.Object) -> SpriteFrame? {
        guard o.kind != "hotspot" else { return nil }
        let wd = Double(o.w + o.d), top = spriteTop(o)
        return SpriteFrame(width: wd * halfWidth, height: wd * halfHeight + top, anchorX: wd * halfHeight, anchorY: top + wd * halfHeight / 2)
    }

    /// hitTest(): ближайший маркер места в радиусе 30, затем объект на клетке (самый глубокий),
    /// затем по рамке спрайта (верхние 80 %).
    public static func hitTest(
        objects: [MapContent.Object],
        camera: Camera,
        view: Size,
        at screen: Point,
        isOpen: (String) -> Bool
    ) -> MapContent.Object? {
        let interactive = objects.filter { $0.isInteractive && isVisible($0, isOpen: isOpen) }
        var best: MapContent.Object?
        var bestDistance = 30.0
        for o in interactive where o.place != nil {
            let m = toScreen(camera, view: view, markerPosition(o))
            let d = hypot(m.x - screen.x, m.y - screen.y)
            if d < bestDistance {
                bestDistance = d
                best = o
            }
        }
        if let best { return best }
        let s = toScene(camera, view: view, screen)
        let gx = Int(floor((s.x / halfWidth + s.y / halfHeight) / 2))
        let gy = Int(floor((s.y / halfHeight - s.x / halfWidth) / 2))
        let onTile = interactive
            .filter { spriteFrame($0) != nil && gx >= $0.x && gx < $0.x + $0.w && gy >= $0.y && gy < $0.y + $0.d }
            .max { $0.depth < $1.depth }
        if let onTile { return onTile }
        return interactive.filter { o in
            guard let f = spriteFrame(o) else { return false }
            let c = center(o)
            return s.x >= c.x - f.anchorX && s.x <= c.x - f.anchorX + f.width
                && s.y >= c.y - f.anchorY && s.y <= c.y - f.anchorY + f.height * 0.8
        }.max { $0.depth < $1.depth }
    }

    /// focusObject(): камера над объектом (на 40 выше центра), масштаб не меньше 1.
    public static func focusTarget(_ o: MapContent.Object, currentZoom: Double?) -> Camera {
        let c = center(o)
        return Camera(x: c.x, y: c.y - 40, z: max(currentZoom ?? 1, 1))
    }

    /// Центр города (кнопка «К центру»): iso(city.focus), масштаб 1.
    public static func home(_ city: MapContent.City) -> Camera {
        let p = iso(city.focus[0], city.focus[1])
        return Camera(x: p.x, y: p.y, z: 1)
    }

    /// Начальная камера: сохранённая (cameras[id]) или «наезд» с introZoom.
    public static func initialCamera(saved: Camera?, city: MapContent.City, size: Int) -> (camera: Camera, animatesIntro: Bool) {
        if let saved { return (clamp(saved, size: size), false) }
        let home = home(city)
        return (clamp(Camera(x: home.x, y: home.y, z: introZoom), size: size), true)
    }

    /// Плавность анимаций камеры и viewBox (easeInOutQuad).
    public static func ease(_ k: Double) -> Double {
        k < 0.5 ? 2 * k * k : 1 - pow(-2 * k + 2, 2) / 2
    }

    /// noise(seed, salt) — детерминированный шум 0…0.999 (как `>>> 0` в JS).
    public static func noise(_ seed: Int, _ salt: Int) -> Double {
        let raw = Int64(seed) &* 1_103_515_245 &+ Int64(salt) &* 12_345
        return Double(UInt32(truncatingIfNeeded: raw) % 1000) / 1000
    }

    /// tileVariant(x, y): 32-битные умножение и XOR, как в JS.
    public static func tileVariant(_ x: Int, _ y: Int) -> Int {
        let a = Int32(truncatingIfNeeded: Int64(x) * 73_856_093)
        let b = Int32(truncatingIfNeeded: Int64(y) * 19_349_663)
        let r = Int((a ^ b) % 3)
        return ((r + 3) % 3)
    }

    /// Ключ открытых глав (lastUnlockKey / groundKey): по нему видно, что открылась новая глава.
    public static func unlockKey(_ unlocked: [String]) -> String {
        unlocked.sorted().joined(separator: "|")
    }
}

/// Обзорная карта (renderMap): проекция proj(), viewBox и контуры GEO.
public enum WorldGeometry {
    /// WORLD_FULL: x, y, w, h.
    public static let fullViewBox: [Double] = [-440, -420, 800, 740]

    /// proj(lon, lat).
    public static func project(lon: Double, lat: Double) -> CityGeometry.Point {
        let k = 40.0, c = cos(23.5 * .pi / 180)
        return CityGeometry.Point((lon - 45) * k * c, -(lat - 23.5) * k)
    }

    /// viewBox выбранного города: [x − 170, y − 150, 340, 400].
    public static func viewBox(city: MapContent.GeoCity?) -> [Double] {
        guard let city else { return fullViewBox }
        let p = project(lon: city.lon, lat: city.lat)
        return [p.x - 170, p.y - 150, 340, 400]
    }

    /// pathOf(): точки контура в координатах SVG (с округлением до 0.1, как toFixed(1)).
    public static func outline(_ points: [[Double]]) -> [CityGeometry.Point] {
        points.map { lonLat in
            let p = project(lon: lonLat[0], lat: lonLat[1])
            return CityGeometry.Point((p.x * 10).rounded() / 10, (p.y * 10).rounded() / 10)
        }
    }
}
