// CityCanvasView.swift
// ZKR-57: сцена карты города — drawCity(), stepCamera(), attachGestures() и hitTest() из index.html.
// Слои Core Animation вместо перерисовки холста: дальний план с параллаксом, земля, тени (радиальный
// градиент .26), пульсирующий ромб выбранного объекта, спрайты (покачивание пальм, мерцание фонарей,
// проявление 900 мс), экранные маркеры «i» с кольцом, покачиванием и подписью при z > .75.
// Камера: перетаскивание с инерцией (×0.9 за кадр 60 Гц, стоп < 0.3), щипок вокруг середины пальцев,
// нажатие (hitTest), анимации easeInOutQuad. Сохранение камеры (saveCam) — после жеста и анимации.

import SwiftUI
import UIKit
import ZikrContent

final class CityCanvasView: UIView, UIGestureRecognizerDelegate {
    struct Marker {
        let objectID: String
        let lit: Bool
        let label: String
    }

    var onTap: ((String?) -> Void)?
    var onCameraSettle: ((CityGeometry.Camera) -> Void)?

    private(set) var camera = CityGeometry.Camera(x: 0, y: 0, z: 1)
    private let city: MapContent.City
    private let size: Int
    private var assets: CitySceneAssets
    private var openChapters: Set<String> = []
    private var markers: [Marker] = []
    private var selectedID: String?
    private var reduceMotion = false
    private var reveal: [String: CFTimeInterval] = [:]
    private var cameraAnimation: (from: CityGeometry.Camera, to: CityGeometry.Camera, start: CFTimeInterval, duration: Double)?
    private var inertia: (x: Double, y: Double)?
    private var isPinching = false
    private var pinchMid: CGPoint = .zero
    private var pinchStartZoom = 1.0
    private var lastPanTranslation: CGPoint = .zero
    private var displayLink: CADisplayLink?
    private var lastTick: CFTimeInterval = 0
    private var hasLaidOut = false
    private var pendingFocus: String?

    private let sceneLayer = CALayer()
    private let groundLayer = CALayer()
    private var farLayers: [CALayer] = []
    private var shadowLayers: [String: CALayer] = [:]
    private var objectLayers: [String: CALayer] = [:]
    private let selectionLayer = CAShapeLayer()
    private let markerLayer = CALayer()
    private var markerViews: [String: (ring: CAShapeLayer, dot: CALayer, label: CALayer)] = [:]
    private static let shadowImage = makeShadowImage()

    init(city: MapContent.City, size: Int, assets: CitySceneAssets, camera: CityGeometry.Camera, animatesIntro: Bool, reveal: Set<String>) {
        self.city = city
        self.size = size
        self.assets = assets
        super.init(frame: .zero)
        self.camera = camera
        let now = CACurrentMediaTime()
        self.reveal = Dictionary(uniqueKeysWithValues: reveal.map { ($0, now) })
        if animatesIntro {
            cameraAnimation = (camera, CityGeometry.Camera(x: camera.x, y: camera.y, z: 1), now, CityGeometry.introDuration)
        }
        backgroundColor = UIColor(named: "Bg2")
        isMultipleTouchEnabled = true
        clipsToBounds = true
        setUpLayers()
        setUpGestures()
        isAccessibilityElement = true
        accessibilityTraits = .image
        accessibilityIdentifier = "map.city.canvas"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Состояние из модели

    func update(open: [String], markers: [Marker], selectedID: String?, reduceMotion: Bool, accessibilityLabel label: String) {
        let openSet = Set(open)
        let visibilityChanged = openSet != openChapters
        openChapters = openSet
        self.reduceMotion = reduceMotion
        accessibilityLabel = label
        if self.selectedID != selectedID {
            self.selectedID = selectedID
            updateSelectionPath()
        }
        let markersChanged = markers.map(\.label) != self.markers.map(\.label) || markers.map(\.lit) != self.markers.map(\.lit)
        self.markers = markers
        if markersChanged { rebuildMarkers() }
        if visibilityChanged { applyVisibility() }
        render(time: CACurrentMediaTime())
        updateDisplayLink()
    }

    func replaceAssets(_ assets: CitySceneAssets) {
        guard assets.groundKey != self.assets.groundKey || assets.cityID != self.assets.cityID else { return }
        self.assets = assets
        setGround()
    }

    /// animateCam / focusObject.
    func perform(_ kind: MapViewModel.CameraRequest.Kind) {
        switch kind {
        case .zoom(let factor): animate(to: CityGeometry.Camera(x: camera.x, y: camera.y, z: camera.z * factor), duration: 0.3)
        case .home: animate(to: CityGeometry.home(city), duration: 0.45)
        case .focus(let id):
            guard hasLaidOut else { pendingFocus = id; return }
            guard let object = city.object(id: id) else { return }
            animate(to: CityGeometry.focusTarget(object, currentZoom: camera.z), duration: 0.45)
        }
    }

    // MARK: - Слои

    private func setUpLayers() {
        sceneLayer.anchorPoint = .zero
        layer.addSublayer(sceneLayer)
        for (index, element) in city.far.enumerated() {
            let far = CALayer()
            far.bounds = CGRect(x: 0, y: 0, width: element.w, height: element.h)
            far.anchorPoint = CGPoint(x: 0.5, y: 1)
            far.contents = index < assets.far.count ? assets.far[index] : nil
            sceneLayer.addSublayer(far)
            farLayers.append(far)
        }
        groundLayer.magnificationFilter = .linear
        sceneLayer.addSublayer(groundLayer)
        setGround()
        for object in city.objects where object.shadow {
            guard assets.sprites[object.id] != nil else { continue }
            let c = CityGeometry.center(object)
            let fw = Double(object.w + object.d) * CityGeometry.halfWidth
            let fh = Double(object.w + object.d) * CityGeometry.halfHeight
            let stretch = 1 + min(object.h, 120) / 160
            let lift = min(object.h, 60)
            let shadow = CALayer()
            shadow.contents = Self.shadowImage
            shadow.bounds = CGRect(x: 0, y: 0, width: fw * 0.45 * stretch * 2, height: fh * 0.4 * 2)
            shadow.position = CGPoint(x: c.x + lift * 0.22, y: c.y + lift * 0.06)
            sceneLayer.addSublayer(shadow)
            shadowLayers[object.id] = shadow
        }
        selectionLayer.lineJoin = .miter
        sceneLayer.addSublayer(selectionLayer)
        for object in city.objects {
            guard let sprite = assets.sprites[object.id] else { continue }
            let f = sprite.frame
            let sprite3 = CALayer()
            sprite3.contents = sprite.image
            sprite3.bounds = CGRect(x: 0, y: 0, width: f.width, height: f.height)
            sprite3.anchorPoint = CGPoint(x: f.anchorX / f.width, y: f.anchorY / f.height)
            let c = CityGeometry.center(object)
            sprite3.position = CGPoint(x: c.x, y: c.y)
            sceneLayer.addSublayer(sprite3)
            objectLayers[object.id] = sprite3
        }
        layer.addSublayer(markerLayer)
        for layer in [sceneLayer, groundLayer, selectionLayer, markerLayer] + farLayers + Array(shadowLayers.values) + Array(objectLayers.values) {
            layer.actions = Self.noActions
        }
    }

    private func setGround() {
        guard let ground = assets.ground else { groundLayer.contents = nil; return }
        groundLayer.contents = ground.image
        groundLayer.frame = CGRect(x: -ground.originX, y: 0, width: ground.width, height: ground.height)
    }

    private func applyVisibility() {
        for object in city.objects {
            let visible = CityGeometry.isVisible(object, isOpen: openChapters.contains)
            objectLayers[object.id]?.isHidden = !visible
            shadowLayers[object.id]?.isHidden = !visible
        }
    }

    private func rebuildMarkers() {
        markerViews.values.forEach { $0.ring.removeFromSuperlayer(); $0.dot.removeFromSuperlayer(); $0.label.removeFromSuperlayer() }
        markerViews = [:]
        let dark = traitCollection.userInterfaceStyle == .dark
        for marker in markers {
            let ring = CAShapeLayer()
            ring.path = UIBezierPath(arcCenter: .zero, radius: 20, startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath
            ring.fillColor = UIColor(red: 227 / 255, green: 194 / 255, blue: 116 / 255, alpha: 0.28).cgColor
            let dot = CALayer()
            dot.contents = Self.markerImage(lit: marker.lit)
            dot.bounds = CGRect(x: 0, y: 0, width: Self.markerSide, height: Self.markerSide)
            let label = CALayer()
            let chip = Self.labelImage(marker.label, dark: dark)
            label.contents = chip
            label.contentsScale = UIScreen.main.scale
            label.bounds = CGRect(origin: .zero, size: chip.map { CGSize(width: CGFloat($0.width) / Self.renderScale, height: CGFloat($0.height) / Self.renderScale) } ?? .zero)
            for item in [ring, dot, label] as [CALayer] {
                item.actions = Self.noActions
                markerLayer.addSublayer(item)
            }
            markerViews[marker.objectID] = (ring, dot, label)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            backgroundColor = UIColor(named: "Bg2")
            rebuildMarkers()
            render(time: CACurrentMediaTime())
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        sceneLayer.frame = bounds
        markerLayer.frame = bounds
        if !hasLaidOut, bounds.width > 0 {
            hasLaidOut = true
            if let focus = pendingFocus {
                pendingFocus = nil
                perform(.focus(focus))
            }
        }
        render(time: CACurrentMediaTime())
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateDisplayLink()
    }

    // MARK: - Цикл (startCityLoop / stepCamera / drawCity)

    /// Цикл крутится, пока есть движение или, без Reduce Motion, всегда (покачивание, пульс, маркеры) — как в вебе.
    private func updateDisplayLink() {
        let busy = window != nil && (!reduceMotion || cameraAnimation != nil || inertia != nil || !reveal.isEmpty || selectedID != nil)
        if busy, displayLink == nil {
            let link = CADisplayLink(target: DisplayLinkProxy(self), selector: #selector(DisplayLinkProxy.tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
            lastTick = CACurrentMediaTime()
        } else if !busy {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    fileprivate func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let frames = max(0.25, min(4, (now - lastTick) * 60))
        lastTick = now
        step(time: now, frames: frames)
        render(time: now)
        updateDisplayLink()
    }

    private func step(time: CFTimeInterval, frames: Double) {
        if let a = cameraAnimation {
            let k = a.duration > 0 ? min(1, (time - a.start) / a.duration) : 1
            let e = CityGeometry.ease(k)
            camera = CityGeometry.clamp(
                CityGeometry.Camera(
                    x: a.from.x + (a.to.x - a.from.x) * e,
                    y: a.from.y + (a.to.y - a.from.y) * e,
                    z: a.from.z + (a.to.z - a.from.z) * e
                ),
                size: size
            )
            if k >= 1 {
                cameraAnimation = nil
                settle()
            }
        }
        if var v = inertia {
            camera.x -= v.x * frames / camera.z
            camera.y -= v.y * frames / camera.z
            let decay = pow(0.9, frames)
            v.x *= decay
            v.y *= decay
            camera = CityGeometry.clamp(camera, size: size)
            if hypot(v.x, v.y) < 0.3 {
                inertia = nil
                settle()
            } else {
                inertia = v
            }
        }
        for (id, start) in reveal where time - start >= 0.9 {
            reveal[id] = nil
        }
    }

    private func render(time: CFTimeInterval) {
        guard bounds.width > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let t = time * 1000
        let z = camera.z
        let transform = CGAffineTransform(translationX: bounds.width / 2, y: bounds.height / 2)
            .scaledBy(x: z, y: z)
            .translatedBy(x: -camera.x, y: -camera.y)
        sceneLayer.sublayerTransform = CATransform3DMakeAffineTransform(transform)
        // Дальний план: смещение с камерой (параллакс), без него при Reduce Motion.
        let mapWidth = Double(size) * 2 * CityGeometry.halfWidth
        for (index, element) in city.far.enumerated() {
            let k = reduceMotion ? 0 : (1 - element.depth) * 0.5
            farLayers[index].position = CGPoint(
                x: element.off * mapWidth + camera.x * k,
                y: -CityGeometry.halfHeight * 2 + camera.y * k * 0.3
            )
        }
        for object in city.objects {
            guard let sprite = objectLayers[object.id], !sprite.isHidden else { continue }
            let revealAlpha = reveal[object.id].map { Float(min(1, max(0, (CACurrentMediaTime() - $0) / 0.9))) } ?? 1
            var alpha = revealAlpha
            if !reduceMotion, object.anim == "glow" { alpha *= Float(0.9 + 0.1 * sin(t / 600)) }
            sprite.opacity = alpha
            shadowLayers[object.id]?.opacity = revealAlpha
            if !reduceMotion, object.anim == "sway" {
                sprite.setAffineTransform(CGAffineTransform(rotationAngle: sin(t / 760 + Double(object.x)) * 0.015))
            } else if object.anim == "sway" {
                sprite.setAffineTransform(.identity)
            }
        }
        renderSelection(t: t)
        renderMarkers(t: t)
        CATransaction.commit()
    }

    private func updateSelectionPath() {
        guard let id = selectedID, let o = city.object(id: id) else {
            selectionLayer.path = nil
            return
        }
        let a = CityGeometry.iso(Double(o.x), Double(o.y))
        let b = CityGeometry.iso(Double(o.x + o.w), Double(o.y))
        let c = CityGeometry.iso(Double(o.x + o.w), Double(o.y + o.d))
        let d = CityGeometry.iso(Double(o.x), Double(o.y + o.d))
        let path = CGMutablePath()
        path.addLines(between: [a, b, c, d].map { CGPoint(x: $0.x, y: $0.y) })
        path.closeSubpath()
        selectionLayer.path = path
    }

    private func renderSelection(t: Double) {
        guard selectionLayer.path != nil else { return }
        let pulse = reduceMotion ? 1 : 0.65 + 0.35 * (0.5 + 0.5 * sin(t / 450))
        selectionLayer.fillColor = Self.gold.withAlphaComponent(0.22 * pulse).cgColor
        selectionLayer.strokeColor = Self.gold.withAlphaComponent(pulse).cgColor
        selectionLayer.lineWidth = 2.5 / max(camera.z, 0.6)
    }

    private func renderMarkers(t: Double) {
        let view = CityGeometry.Size(width: bounds.width, height: bounds.height)
        let allGold = openChapters.contains("ch19")
        let showsLabels = camera.z > CityGeometry.labelZoom
        for marker in markers {
            guard let object = city.object(id: marker.objectID), let views = markerViews[marker.objectID] else { continue }
            var p = CityGeometry.toScreen(camera, view: view, CityGeometry.markerPosition(object))
            if !reduceMotion { p.y += sin(t / 700 + Double(object.x)) * 2 }
            let point = CGPoint(x: p.x, y: p.y)
            views.ring.isHidden = !(marker.lit && (allGold || !reduceMotion))
            views.ring.position = point
            let r = reduceMotion ? 1 : (20 + 2 * sin(t / 500)) / 20
            views.ring.setAffineTransform(CGAffineTransform(scaleX: r, y: r))
            views.dot.position = point
            views.label.isHidden = !showsLabels
            views.label.position = CGPoint(x: point.x, y: point.y + 19 + views.label.bounds.height / 2)
        }
    }

    // MARK: - Жесты (attachGestures)

    private func setUpGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        [pan, pinch, tap].forEach(addGestureRecognizer)
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        !(g is UITapGestureRecognizer || other is UITapGestureRecognizer)
    }

    /// pointerdown: любое касание останавливает инерцию и анимацию камеры.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        inertia = nil
        cameraAnimation = nil
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        switch g.state {
        case .began:
            lastPanTranslation = .zero
            inertia = nil
            cameraAnimation = nil
        case .changed:
            let translation = g.translation(in: self)
            let dx = translation.x - lastPanTranslation.x, dy = translation.y - lastPanTranslation.y
            lastPanTranslation = translation
            guard !isPinching else { return }
            camera.x -= dx / camera.z
            camera.y -= dy / camera.z
            camera = CityGeometry.clamp(camera, size: size)
            render(time: CACurrentMediaTime())
        case .ended, .cancelled:
            guard !isPinching else { return }
            // vel = d·16/dt (px за 16 мс); инерция, если скорость > 2 и палец не стоял.
            let v = g.velocity(in: self)
            let vx = v.x * 0.016, vy = v.y * 0.016
            if !reduceMotion, g.state == .ended, hypot(vx, vy) > 2 {
                inertia = (vx, vy)
            }
            settle()
            updateDisplayLink()
        default:
            break
        }
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        let view = CityGeometry.Size(width: bounds.width, height: bounds.height)
        switch g.state {
        case .began:
            isPinching = true
            inertia = nil
            cameraAnimation = nil
            pinchStartZoom = camera.z
            pinchMid = g.location(in: self)
        case .changed:
            let mid = g.location(in: self)
            let before = CityGeometry.toScene(camera, view: view, CityGeometry.Point(pinchMid.x, pinchMid.y))
            camera.z = min(CityGeometry.maxZoom, max(CityGeometry.minZoom, pinchStartZoom * g.scale))
            let after = CityGeometry.toScene(camera, view: view, CityGeometry.Point(mid.x, mid.y))
            camera.x += before.x - after.x
            camera.y += before.y - after.y
            pinchMid = mid
            camera = CityGeometry.clamp(camera, size: size)
            render(time: CACurrentMediaTime())
        case .ended, .cancelled, .failed:
            isPinching = false
            settle()
        default:
            break
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        let p = g.location(in: self)
        let hit = CityGeometry.hitTest(
            objects: city.objects,
            camera: camera,
            view: CityGeometry.Size(width: bounds.width, height: bounds.height),
            at: CityGeometry.Point(p.x, p.y),
            isOpen: openChapters.contains
        )
        onTap?(hit?.id)
    }

    private func animate(to target: CityGeometry.Camera, duration: Double) {
        if reduceMotion {
            camera = CityGeometry.clamp(target, size: size)
            cameraAnimation = nil
            settle()
            render(time: CACurrentMediaTime())
            return
        }
        cameraAnimation = (camera, target, CACurrentMediaTime(), duration)
        inertia = nil
        updateDisplayLink()
    }

    private func settle() {
        onCameraSettle?(camera)
    }

    // MARK: - Растры маркеров

    static let markerSide: CGFloat = 36
    private static let renderScale = UIScreen.main.scale
    private static let gold = UIColor(red: 227 / 255, green: 194 / 255, blue: 116 / 255, alpha: 1)
    private static let noActions: [String: CAAction] = ["position": NSNull(), "bounds": NSNull(), "transform": NSNull(),
                                                        "opacity": NSNull(), "contents": NSNull(), "hidden": NSNull(),
                                                        "path": NSNull(), "fillColor": NSNull(), "strokeColor": NSNull(),
                                                        "lineWidth": NSNull(), "sublayerTransform": NSNull()]
    private static var markerCache: [Bool: CGImage] = [:]

    /// Круг r 15 (#C9A24D / #1B2A44), обводка 2 (#FFF3D1 / #C2A05A), «i» Georgia bold 17.
    static func markerImage(lit: Bool) -> CGImage? {
        if let cached = markerCache[lit] { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        let image = UIGraphicsImageRenderer(size: CGSize(width: markerSide, height: markerSide), format: format).image { context in
            let c = CGPoint(x: markerSide / 2, y: markerSide / 2)
            let circle = UIBezierPath(arcCenter: c, radius: 15, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            UIColor(hex: lit ? 0xC9A24D : 0x1B2A44).setFill()
            circle.fill()
            circle.lineWidth = 2
            UIColor(hex: lit ? 0xFFF3D1 : 0xC2A05A).setStroke()
            circle.stroke()
            let font = UIFont(name: "Georgia-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
            let text = NSAttributedString(string: "i", attributes: [.font: font, .foregroundColor: lit ? UIColor(hex: 0x1B2A44) : UIColor.white])
            let size = text.size()
            // textBaseline "middle" на (mx, my + 1): середина em-квадрата.
            let baseline = c.y + 1 + (font.ascender + font.descender) / 2
            text.draw(at: CGPoint(x: c.x - size.width / 2, y: baseline - font.ascender))
            _ = context
        }.cgImage
        markerCache[lit] = image
        return image
    }

    /// Подпись: 600 12 px, плашка шириной текст + 12, высота 18, радиус 9.
    static func labelImage(_ text: String, dark: Bool) -> CGImage? {
        guard !text.isEmpty else { return nil }
        let font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: dark ? UIColor(hex: 0xEFE8DA) : UIColor(hex: 0x1C2333),
        ])
        let width = ceil(attributed.size().width) + 12
        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: 18), format: format).image { _ in
            (dark ? UIColor(red: 26 / 255, green: 35 / 255, blue: 52 / 255, alpha: 0.88) : UIColor(red: 246 / 255, green: 242 / 255, blue: 234 / 255, alpha: 0.9)).setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: 18), cornerRadius: 9).fill()
            let size = attributed.size()
            let baseline = 9.5 + (font.ascender + font.descender) / 2
            attributed.draw(at: CGPoint(x: (width - size.width) / 2, y: baseline - font.ascender))
        }.cgImage
    }

    /// Радиальный градиент тени: rgba(0,0,0,.26) в центре → 0 на краю (масштабируется рамкой слоя).
    private static func makeShadowImage() -> CGImage? {
        let side: CGFloat = 64
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            let colors = [UIColor(white: 0, alpha: 0.26).cgColor, UIColor(white: 0, alpha: 0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) else { return }
            let c = CGPoint(x: side / 2, y: side / 2)
            context.cgContext.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: side / 2, options: [])
        }.cgImage
    }
}

/// CADisplayLink держит цель сильно: прокси со слабой ссылкой.
private final class DisplayLinkProxy {
    weak var view: CityCanvasView?

    init(_ view: CityCanvasView) { self.view = view }

    @objc func tick(_ link: CADisplayLink) {
        guard let view else {
            link.invalidate()
            return
        }
        view.tick(link)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

// MARK: - SwiftUI

/// Сцена города для MapView. Камера живёт в CityCanvasView; модель получает её через onCameraSettle.
struct CityCanvas: UIViewRepresentable {
    let city: MapContent.City
    let size: Int
    let assets: CitySceneAssets
    let initialCamera: CityGeometry.Camera
    let animatesIntro: Bool
    let reveal: Set<String>
    let open: [String]
    let markers: [CityCanvasView.Marker]
    let selectedID: String?
    let request: MapViewModel.CameraRequest?
    let reduceMotion: Bool
    let accessibilityLabel: String
    let onTap: (String?) -> Void
    let onCameraSettle: (CityGeometry.Camera) -> Void
    let onRequestHandled: (Int) -> Void

    final class Coordinator {
        var lastRequestID: Int?
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        // Запрос, поставленный до появления сцены (focus из openCity), выполняется при создании.
        return coordinator
    }

    func makeUIView(context: Context) -> CityCanvasView {
        let view = CityCanvasView(
            city: city, size: size, assets: assets, camera: initialCamera, animatesIntro: animatesIntro, reveal: reveal
        )
        view.onTap = onTap
        view.onCameraSettle = onCameraSettle
        return view
    }

    func updateUIView(_ view: CityCanvasView, context: Context) {
        view.onTap = onTap
        view.onCameraSettle = onCameraSettle
        view.replaceAssets(assets)
        view.update(open: open, markers: markers, selectedID: selectedID, reduceMotion: reduceMotion, accessibilityLabel: accessibilityLabel)
        if let request, request.id != context.coordinator.lastRequestID {
            context.coordinator.lastRequestID = request.id
            view.perform(request.kind)
            let id = request.id
            DispatchQueue.main.async { onRequestHandled(id) }
        }
    }
}
