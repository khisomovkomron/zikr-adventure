// WorldMapCanvas.swift
// ZKR-57: обзорная карта — SVG renderMap() в index.html: Африка, Синай, полуостров (land, border 50 %),
// Саудовская Аравия (country, border 2), горы (треугольники mount), путь хиджры (после ch08), маркеры
// Мекки и Медины (кольцо и крупная подпись у выбранного). viewBox анимируется (selectWorldCity: 450 мс).

import SwiftUI
import ZikrContent

struct WorldMapCanvas: View, Animatable {
    var viewBox: [Double]
    let geo: MapContent.Geo
    let selected: String?
    let showsHijra: Bool
    let label: (String) -> String
    let onSelect: (String) -> Void
    let onBackground: () -> Void

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get { .init(.init(viewBox[0], viewBox[1]), .init(viewBox[2], viewBox[3])) }
        set { viewBox = [newValue.first.first, newValue.first.second, newValue.second.first, newValue.second.second] }
    }

    /// preserveAspectRatio xMidYMid meet.
    private func transform(_ size: CGSize) -> (scale: CGFloat, dx: CGFloat, dy: CGFloat) {
        let scale = min(size.width / viewBox[2], size.height / viewBox[3])
        return (scale, (size.width - viewBox[2] * scale) / 2 - viewBox[0] * scale, (size.height - viewBox[3] * scale) / 2 - viewBox[1] * scale)
    }

    var body: some View {
        GeometryReader { proxy in
            let t = transform(proxy.size)
            let map = { (p: CityGeometry.Point) in CGPoint(x: p.x * t.scale + t.dx, y: p.y * t.scale + t.dy) }
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for (points, fill, width, opacity) in [
                        (geo.africa, Theme.Color.mapLand, 1.0, 0.5), (geo.sinai, Theme.Color.mapLand, 1.0, 0.5),
                        (geo.peninsula, Theme.Color.mapLand, 1.0, 0.5), (geo.saudi, Theme.Color.mapCountry, 2.0, 1.0),
                    ] {
                        var path = Path()
                        path.addLines(WorldGeometry.outline(points).map(map))
                        path.closeSubpath()
                        context.fill(path, with: .color(fill))
                        context.stroke(path, with: .color(Theme.Color.mapBorder.opacity(opacity)), lineWidth: width * t.scale)
                    }
                    for (i, lonLat) in geo.mountains.enumerated() {
                        let p = WorldGeometry.project(lon: lonLat[0], lat: lonLat[1])
                        let h: Double = i % 2 == 1 ? 12 : 16
                        var path = Path()
                        path.addLines([map(.init(p.x - 11, p.y)), map(.init(p.x, p.y - h)), map(.init(p.x + 11, p.y))])
                        path.closeSubpath()
                        context.fill(path, with: .color(Theme.Color.mapMount))
                        context.stroke(path, with: .color(.black.opacity(0.2)), lineWidth: t.scale)
                    }
                    if showsHijra, let mecca = geo.cities["mecca"], let medina = geo.cities["medina"] {
                        let m = WorldGeometry.project(lon: mecca.lon, lat: mecca.lat)
                        let d = WorldGeometry.project(lon: medina.lon, lat: medina.lat)
                        var path = Path()
                        path.move(to: map(m))
                        path.addCurve(to: map(d), control1: map(.init(m.x - 60, m.y - 80)), control2: map(.init(d.x - 50, d.y + 60)))
                        context.stroke(
                            path, with: .color(Theme.Color.mapHijra),
                            style: StrokeStyle(lineWidth: Theme.Map.hijraWidth * t.scale, dash: [9 * t.scale, 7 * t.scale])
                        )
                    }
                    for id in MapContent.cityIDs {
                        guard let city = geo.cities[id] else { continue }
                        let c = map(WorldGeometry.project(lon: city.lon, lat: city.lat))
                        let on = selected == id
                        if on {
                            let r = Theme.Map.worldRing * t.scale
                            let ring = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                            context.fill(ring, with: .color(Theme.Color.mapMarkerStroke.opacity(0x33 / 255)))
                            context.stroke(ring, with: .color(Theme.Color.mapMarkerStroke), lineWidth: Theme.Map.worldStroke * t.scale)
                        }
                        let r = (on ? Theme.Map.worldDotSelected : Theme.Map.worldDot) * t.scale
                        let dot = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                        context.fill(dot, with: .color(Theme.Color.mapMarker))
                        context.stroke(dot, with: .color(Theme.Color.mapMarkerStroke), lineWidth: Theme.Map.worldStroke * t.scale)
                        let size = (on ? Theme.Map.worldLabelSelected : Theme.Map.worldLabel) * t.scale
                        let text = context.resolve(Text(label(id)).font(.system(size: size, weight: .bold)).foregroundColor(Theme.Color.text))
                        // <text x="x + 17" y="y + 5">: левый край по базовой линии.
                        let font = UIFont.systemFont(ofSize: size, weight: .bold)
                        context.draw(text, at: CGPoint(x: c.x + 17 * t.scale, y: c.y + 5 * t.scale - font.ascender), anchor: .topLeading)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onBackground() }
                .accessibilityElement()
                .accessibilityAddTraits(.isImage)

                ForEach(MapContent.cityIDs, id: \.self) { id in
                    if let city = geo.cities[id] {
                        let c = map(WorldGeometry.project(lon: city.lon, lat: city.lat))
                        let side = max(Theme.Size.touch, 2 * Theme.Map.worldHit * t.scale)
                        Button { onSelect(id) } label: {
                            Color.clear.frame(width: side, height: side).contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .position(c)
                        .accessibilityLabel(label(id))
                        .accessibilityAddTraits(selected == id ? [.isButton, .isSelected] : .isButton)
                        .accessibilityIdentifier("map.world.marker.\(id)")
                    }
                }
            }
        }
    }
}
