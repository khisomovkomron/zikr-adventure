// MapSpriteFactory.swift
// ZKR-57: спрайты карты города рисует код веба. map-draw.js (drawObject, tileSprite, farSprite, drawOverlay,
// renderGround из index.html, извлечены tools/zikr-map-from-web.mjs без изменений) выполняется в JavaScriptCore
// поверх записывающего Canvas 2D (map-canvas-shim.js), а команды холстов воспроизводятся в Core Graphics.
// Масштаб растра — как в вебе: DPR 2 для спрайтов, 1.5 для земли (renderGround).
// Не потокобезопасен: один экземпляр — одна очередь (сборка сцены города вне главного потока).

#if canImport(JavaScriptCore) && canImport(CoreGraphics)
import CoreGraphics
import Foundation
import JavaScriptCore
import ZikrCore

/// Растр спрайта объекта: размер холста W × H (pt сцены) и якорь (ax, ay) относительно objCenter.
public struct MapSprite: @unchecked Sendable {
    public let image: CGImage
    public let frame: CityGeometry.SpriteFrame
}

/// Земля города (тайлы + видимые наложения): рисуется в (-ox, 0, W, H) сцены.
public struct MapGround: @unchecked Sendable {
    public let image: CGImage
    public let originX: Double
    public let width: Double
    public let height: Double
}

public final class MapSpriteFactory {
    public static let shimResource = "map-canvas-shim"
    public static let drawResource = "map-draw"

    private let context: JSContext
    private var images: [Int: CGImage] = [:]
    private var lastException: String?

    /// - Parameter open: открытые главы (isOpen: предпросмотр или unlocked) — для наложений земли.
    public init(open: [String]) throws {
        let bundle = Bundle.module
        guard
            let shimURL = bundle.url(forResource: Self.shimResource, withExtension: "js"),
            let drawURL = bundle.url(forResource: Self.drawResource, withExtension: "js"),
            let shim = try? String(contentsOf: shimURL, encoding: .utf8),
            let draw = try? String(contentsOf: drawURL, encoding: .utf8),
            let context = JSContext()
        else { throw AppError.storageRead("map-draw.js") }
        self.context = context
        context.exceptionHandler = { [weak self] _, value in
            self?.lastException = value?.toString()
        }
        context.evaluateScript(shim)
        context.evaluateScript(draw)
        try check("map-draw.js")
        setOpen(open)
    }

    public func setOpen(_ open: [String]) {
        context.objectForKeyedSubscript("__reset")?.call(withArguments: [open, false])
    }

    /// drawObject(o). nil — hotspot (без спрайта) или ошибка скрипта.
    public func sprite(for object: MapContent.Object) -> MapSprite? {
        guard
            let json = Self.json(object),
            let result = evaluate("__sprite(\(json))"),
            let info = Self.dictionary(result),
            let id = info["canvas"] as? Int,
            let image = image(canvas: id)
        else { return nil }
        let frame = CityGeometry.SpriteFrame(
            width: Self.number(info["W"]),
            height: Self.number(info["H"]),
            anchorX: Self.number(info["ax"]),
            anchorY: Self.number(info["ay"])
        )
        return MapSprite(image: image, frame: frame)
    }

    /// farSprite(el): силуэт дальнего плана (W × H = el.w × el.h).
    public func far(_ element: MapContent.Far) -> CGImage? {
        guard let json = Self.json(element), let result = evaluate("__far(\(json))"), let id = Int(result) else { return nil }
        return image(canvas: id)
    }

    /// renderGround(city): тайлы 40 × 40 и наложения открытых слоёв (маршруты — последними).
    public func ground(city: MapContent.City, unlocked: [String], preview: Bool) -> MapGround? {
        guard
            let terrain = Self.json(city.terrain),
            let overlays = Self.json(city.overlays),
            let unlockedJSON = Self.json(unlocked),
            let result = evaluate("__ground(\(terrain), \(overlays), \(unlockedJSON), \(preview))"),
            let info = Self.dictionary(result),
            let id = info["canvas"] as? Int,
            let image = image(canvas: id)
        else { return nil }
        return MapGround(image: image, originX: Self.number(info["ox"]), width: Self.number(info["W"]), height: Self.number(info["H"]))
    }

    // MARK: - JavaScriptCore

    private func evaluate(_ script: String) -> String? {
        lastException = nil
        let value = context.evaluateScript(script)
        if let lastException {
            Log.zikr.error("map-draw.js: \(lastException, privacy: .public)")
            return nil
        }
        return value?.toString()
    }

    private func check(_ name: String) throws {
        if let lastException {
            Log.zikr.error("\(name, privacy: .public): \(lastException, privacy: .public)")
            throw AppError.decoding(name)
        }
    }

    private func image(canvas id: Int) -> CGImage? {
        if let cached = images[id] { return cached }
        guard
            let text = evaluate("__canvasJSON(\(id))"),
            let info = Self.dictionary(text),
            let ops = info["ops"] as? [[Any]]
        else { return nil }
        let replay = CanvasReplay(width: Int(Self.number(info["w"])), height: Int(Self.number(info["h"]))) { [weak self] in
            self?.image(canvas: $0)
        }
        guard let image = replay?.run(ops) else { return nil }
        images[id] = image
        return image
    }

    private static func json<T: Encodable>(_ value: T) -> String? {
        (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) }
    }

    private static func dictionary(_ text: String) -> [String: Any]? {
        text.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    static func number(_ value: Any?) -> Double {
        (value as? NSNumber)?.doubleValue ?? 0
    }
}

// MARK: - Воспроизведение Canvas 2D в Core Graphics

/// Команды холста map-canvas-shim.js → CGContext. Путь и преобразование ведутся здесь (как в Canvas:
/// fill/stroke не сбрасывают путь, точки пути — в преобразовании на момент добавления), обрезка — в CGContext.
struct CanvasReplay {
    private let context: CGContext
    private let height: Int
    private let imageFor: (Int) -> CGImage?

    init?(width: Int, height: Int, imageFor: @escaping (Int) -> CGImage?) {
        guard
            width > 0, height > 0,
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }
        // Canvas: начало координат сверху слева, ось y вниз.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        self.context = context
        self.height = height
        self.imageFor = imageFor
    }

    func run(_ ops: [[Any]]) -> CGImage? {
        var transform = CGAffineTransform.identity
        var stack: [CGAffineTransform] = []
        var path = CGMutablePath()
        for op in ops {
            guard let name = op.first as? String else { continue }
            let n = { (i: Int) -> CGFloat in CGFloat(MapSpriteFactory.number(op.count > i ? op[i] : nil)) }
            switch name {
            case "save":
                stack.append(transform)
                context.saveGState()
            case "restore":
                if let last = stack.popLast() {
                    transform = last
                    context.restoreGState()
                }
            case "scale": transform = CGAffineTransform(scaleX: n(1), y: n(2)).concatenating(transform)
            case "translate": transform = CGAffineTransform(translationX: n(1), y: n(2)).concatenating(transform)
            case "rotate": transform = CGAffineTransform(rotationAngle: n(1)).concatenating(transform)
            case "setTransform": transform = CGAffineTransform(a: n(1), b: n(2), c: n(3), d: n(4), tx: n(5), ty: n(6))
            case "begin": path = CGMutablePath()
            case "close": if !path.isEmpty { path.closeSubpath() }
            case "move": path.move(to: CGPoint(x: n(1), y: n(2)), transform: transform)
            case "line":
                let point = CGPoint(x: n(1), y: n(2))
                if path.isEmpty { path.move(to: point, transform: transform) } else { path.addLine(to: point, transform: transform) }
            case "quad":
                if path.isEmpty { path.move(to: CGPoint(x: n(1), y: n(2)), transform: transform) }
                path.addQuadCurve(to: CGPoint(x: n(3), y: n(4)), control: CGPoint(x: n(1), y: n(2)), transform: transform)
            case "bezier":
                if path.isEmpty { path.move(to: CGPoint(x: n(1), y: n(2)), transform: transform) }
                path.addCurve(
                    to: CGPoint(x: n(5), y: n(6)), control1: CGPoint(x: n(1), y: n(2)), control2: CGPoint(x: n(3), y: n(4)),
                    transform: transform
                )
            case "rect": path.addRect(CGRect(x: n(1), y: n(2), width: n(3), height: n(4)), transform: transform)
            case "ellipse":
                let local = CGAffineTransform(translationX: n(1), y: n(2)).rotated(by: n(5)).scaledBy(x: n(3), y: n(4))
                let start = n(6), end = n(7), counter = (op.count > 8 ? op[8] as? Bool : nil) ?? false
                if abs(end - start) >= 2 * .pi - 1e-9 {
                    path.addEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2), transform: local.concatenating(transform))
                } else {
                    path.addArc(
                        center: .zero, radius: 1, startAngle: start, endAngle: end, clockwise: counter,
                        transform: local.concatenating(transform)
                    )
                }
            case "fill": fill(path, style: op[safe: 1], alpha: n(2), composite: op[safe: 3] as? String, transform: transform)
            case "stroke":
                stroke(path, style: op[safe: 1], alpha: n(2), composite: op[safe: 3] as? String, line: Array(op.dropFirst(4)), transform: transform)
            case "fillRect":
                let rect = CGMutablePath()
                rect.addRect(CGRect(x: n(1), y: n(2), width: n(3), height: n(4)), transform: transform)
                fill(rect, style: op[safe: 5], alpha: n(6), composite: op[safe: 7] as? String, transform: transform)
            case "strokeRect":
                let rect = CGMutablePath()
                rect.addRect(CGRect(x: n(1), y: n(2), width: n(3), height: n(4)), transform: transform)
                stroke(rect, style: op[safe: 5], alpha: n(6), composite: op[safe: 7] as? String, line: Array(op.dropFirst(8)), transform: transform)
            case "clearRect":
                context.saveGState()
                context.concatenate(transform)
                context.clear(CGRect(x: n(1), y: n(2), width: n(3), height: n(4)))
                context.restoreGState()
            case "clip":
                if !path.isEmpty {
                    context.addPath(path)
                    context.clip()
                }
            case "image":
                guard let id = op[safe: 1] as? Int, let image = imageFor(id) else { continue }
                context.saveGState()
                paint(alpha: n(6), composite: op[safe: 7] as? String)
                context.concatenate(transform)
                context.translateBy(x: n(2), y: n(3) + n(5))
                context.scaleBy(x: 1, y: -1)
                context.draw(image, in: CGRect(x: 0, y: 0, width: n(4), height: n(5)))
                context.restoreGState()
            default:
                continue
            }
        }
        return context.makeImage()
    }

    private func paint(alpha: CGFloat, composite: String?) {
        context.setAlpha(alpha)
        switch composite {
        case "destination-in": context.setBlendMode(.destinationIn)
        case "destination-out": context.setBlendMode(.destinationOut)
        case "source-atop": context.setBlendMode(.sourceAtop)
        case "multiply": context.setBlendMode(.multiply)
        default: context.setBlendMode(.normal)
        }
    }

    private func fill(_ path: CGPath, style: Any?, alpha: CGFloat, composite: String?, transform: CGAffineTransform) {
        guard !path.isEmpty else { return }
        context.saveGState()
        paint(alpha: alpha, composite: composite)
        context.addPath(path)
        if let color = (style as? String).flatMap(CanvasColor.parse) {
            context.setFillColor(color)
            context.fillPath()
        } else if let gradient = style as? [String: Any] {
            context.clip()
            context.concatenate(transform)
            drawGradient(gradient)
        }
        context.restoreGState()
    }

    private func stroke(_ path: CGPath, style: Any?, alpha: CGFloat, composite: String?, line: [Any], transform: CGAffineTransform) {
        guard !path.isEmpty else { return }
        context.saveGState()
        paint(alpha: alpha, composite: composite)
        // Толщина и штрих — в пространстве пользователя (как Canvas): путь переводится обратно в него.
        context.concatenate(transform)
        context.addPath(path.copy(using: [transform.inverted()]) ?? path)
        context.setLineWidth(CGFloat(MapSpriteFactory.number(line[safe: 0])))
        context.setLineCap(Self.cap(line[safe: 1] as? String))
        context.setLineJoin(Self.join(line[safe: 2] as? String))
        context.setMiterLimit(10)
        var dash = ((line[safe: 3] as? [Any]) ?? []).map { CGFloat(MapSpriteFactory.number($0)) }
        if dash.count % 2 == 1 { dash += dash }
        if !dash.isEmpty, dash.contains(where: { $0 > 0 }) { context.setLineDash(phase: 0, lengths: dash) }
        if let color = (style as? String).flatMap(CanvasColor.parse) {
            context.setStrokeColor(color)
            context.strokePath()
        } else if let gradient = style as? [String: Any] {
            context.replacePathWithStrokedPath()
            context.clip()
            drawGradient(gradient)
        }
        context.restoreGState()
    }

    private func drawGradient(_ info: [String: Any]) {
        let c = ((info["c"] as? [Any]) ?? []).map { CGFloat(MapSpriteFactory.number($0)) }
        let stops = (info["stops"] as? [[Any]]) ?? []
        let colors = stops.compactMap { ($0[safe: 1] as? String).flatMap(CanvasColor.parse) }
        let locations = stops.map { CGFloat(MapSpriteFactory.number($0[safe: 0])) }
        guard
            colors.count == stops.count, !colors.isEmpty,
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)
        else { return }
        let options: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        if info["type"] as? String == "radial", c.count == 6 {
            context.drawRadialGradient(
                gradient, startCenter: CGPoint(x: c[0], y: c[1]), startRadius: c[2],
                endCenter: CGPoint(x: c[3], y: c[4]), endRadius: c[5], options: options
            )
        } else if c.count == 4 {
            context.drawLinearGradient(gradient, start: CGPoint(x: c[0], y: c[1]), end: CGPoint(x: c[2], y: c[3]), options: options)
        }
    }

    private static func cap(_ value: String?) -> CGLineCap {
        switch value {
        case "round": return .round
        case "square": return .square
        default: return .butt
        }
    }

    private static func join(_ value: String?) -> CGLineJoin {
        switch value {
        case "round": return .round
        case "bevel": return .bevel
        default: return .miter
        }
    }
}

/// Цвета CSS из кода графики: #rgb, #rrggbb, #rrggbbaa, rgb(), rgba().
public enum CanvasColor {
    public static func parse(_ text: String) -> CGColor? {
        components(text).map { CGColor(srgbRed: $0[0], green: $0[1], blue: $0[2], alpha: $0[3]) }
    }

    /// [r, g, b, a] в 0…1.
    public static func components(_ text: String) -> [CGFloat]? {
        let s = text.trimmingCharacters(in: .whitespaces).lowercased()
        if s.hasPrefix("#") {
            var hex = String(s.dropFirst())
            if hex.count == 3 || hex.count == 4 { hex = hex.map { "\($0)\($0)" }.joined() }
            guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else { return nil }
            let v = hex.count == 6 ? (value << 8) | 0xFF : value
            return [24, 16, 8, 0].map { CGFloat((v >> $0) & 0xFF) / 255 }
        }
        if s.hasPrefix("rgb"), let open = s.firstIndex(of: "("), let close = s.lastIndex(of: ")") {
            let parts = s[s.index(after: open)..<close].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count >= 3 else { return nil }
            return [CGFloat(parts[0] / 255), CGFloat(parts[1] / 255), CGFloat(parts[2] / 255), CGFloat(parts.count > 3 ? parts[3] : 1)]
        }
        if s == "transparent" { return [0, 0, 0, 0] }
        return nil
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
