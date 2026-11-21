import SwiftUI
import ZikrCore

struct QiblaView: View {
    @ObservedObject var model: QiblaViewModel
    @ObservedObject var localization: LocalizationService
    @Environment(\.scenePhase) private var phase
    @State private var isPresented = false
    private func tr(_ key: L10nKey) -> String { localization.tr(key) }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.s6) {
                Text(tr(.qiblaTitle)).themeFont(.headingLG)
                    .accessibilityAddTraits(.isHeader).frame(maxWidth: .infinity, alignment: .leading)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let offset = model.offset(at: context.date)
                    let north = model.northHeading(at: context.date)
                    let bearing = model.bearing(at: context.date)
                    VStack(spacing: Theme.Space.s5) {
                        Text(tr(offset != nil ? .qiblaLive : north != nil ? .qiblaNorthOnly : .qiblaWaiting))
                            .themeFont(.footnote).foregroundColor(Theme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                        QiblaDial(offset: offset, northHeading: north,
                                  bearingText: offset != nil ? bearing.map { localization.format($0, maximumFractionDigits: 0) + "°" } : nil,
                                  northLabel: tr(.qiblaNorthLetter), kaabaLabel: tr(.qiblaKaaba))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(tr(offset != nil ? .qiblaKaaba : .qiblaNorthOnly))
                        .accessibilityValue(offset.map { localization.tr(.qiblaTurnValue, localization.format($0, maximumFractionDigits: 0)) }
                            ?? tr(north != nil ? .qiblaNorthOnly : .qiblaWaiting))
                        .accessibilityIdentifier("qibla.dial")
                    }
                }
                if !model.hasLocationPermission {
                    VStack(spacing: Theme.Space.s3) {
                        Text(tr(.qiblaPermissionNote)).themeFont(.footnote)
                            .foregroundColor(Theme.Color.textSecondary).multilineTextAlignment(.center)
                        AppButton(title: tr(model.isDenied ? .qiblaOpenSettings : .qiblaUsePhone), kind: .primary) {
                            if model.isDenied {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            } else { model.usePhoneLocation() }
                        }.accessibilityIdentifier("qibla.usePhone")
                    }
                } else if model.locationFailed {
                    AppButton(title: tr(.qiblaRetry), kind: .secondary) { model.usePhoneLocation() }
                }
            }
            .padding(.horizontal, Theme.Space.s3)
            .padding(.top, Theme.Space.s4).padding(.bottom, Theme.Space.screenBottom)
        }
        .foregroundColor(Theme.Color.text).background(Theme.Color.bg.ignoresSafeArea())
        .accessibilityIdentifier("qibla.screen")
        .onAppear { isPresented = true; if phase == .active { model.start() } }
        .onDisappear { isPresented = false; model.stop() }
        .onChange(of: phase) { if $0 == .active && isPresented { model.start() } else { model.stop() } }
    }
}

private struct QiblaDial: View {
    let offset: Double?
    let northHeading: Double?
    let bearingText: String?
    let northLabel: String
    let kaabaLabel: String

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            ZStack {
                Circle().fill(Theme.Color.surface)
                QiblaArabesque().stroke(Theme.Color.accent.opacity(0.28), lineWidth: 0.75)
                    .padding(side * 0.17).accessibilityHidden(true)
                Circle().stroke(Theme.Color.accent.opacity(0.5), lineWidth: 1)
                Circle().stroke(Theme.Color.accent.opacity(0.25), lineWidth: 1).padding(side * 0.035)
                Circle().stroke(Theme.Color.accent.opacity(0.5), lineWidth: 1).padding(side * 0.15)
                ForEach(0..<60) { tick in
                    Rectangle().fill(tick % 5 == 0 ? Theme.Color.accent : Theme.Color.divider)
                        .frame(width: tick % 5 == 0 ? 2 : 1, height: tick % 5 == 0 ? 14 : 6)
                        .offset(y: -side * 0.435)
                        .rotationEffect(.degrees(Double(tick) * 6 - (northHeading ?? 0)))
                }
                // Самостоятельный маркер севера присутствует и при работающей кибле.
                Text(northLabel).themeFont(.bodyStrong).foregroundColor(Theme.Color.qiblaNorth)
                    .padding(Theme.Space.s1).background(Theme.Color.surface).clipShape(Circle())
                    .rotationEffect(.degrees(northHeading ?? 0))
                    .offset(y: -side * 0.435).rotationEffect(.degrees(-(northHeading ?? 0)))
                if let offset {
                    Circle().trim(from: 0, to: 30.0 / 360)
                        .stroke(Theme.Color.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-105 + offset)).padding(side * 0.035)
                    ForEach([-15.0, 15.0], id: \.self) { angle in
                        Text(angle < 0 ? "−15°" : "+15°").themeFont(.caption)
                            .foregroundColor(Theme.Color.accent)
                            .padding(Theme.Space.s1).background(Theme.Color.surface).clipShape(Capsule())
                            .rotationEffect(.degrees(-(offset + angle)))
                            .offset(y: -side * 0.34).rotationEffect(.degrees(offset + angle))
                    }
                }
                // Гранёная стрелка: золото с одной стороны, тёмный металл с другой.
                if offset != nil || northHeading != nil {
                    needle(side: side).rotationEffect(.degrees(offset ?? -(northHeading ?? 0)))
                }
                Circle().fill(Theme.Color.primary).frame(width: side * 0.075, height: side * 0.075)
                    .overlay(Circle().stroke(Theme.Color.gold, lineWidth: 2))
                VStack(spacing: Theme.Space.s1) {
                    Text(bearingText == nil ? northLabel : kaabaLabel).themeFont(.caption)
                    if let bearingText { Text(bearingText).themeFont(.headingSM) }
                }
                .padding(.horizontal, Theme.Space.s3).padding(.vertical, Theme.Space.s2)
                .background(Theme.Color.surface).clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                .offset(y: side * 0.26)
            }.frame(width: side, height: side)
        }.aspectRatio(1, contentMode: .fit)
    }

    private func needle(side: CGFloat) -> some View {
        ZStack {
            QiblaNeedleHalf(left: true).fill(Theme.Color.goldLight)
            QiblaNeedleHalf(left: false).fill(Theme.Color.primary)
            QiblaNeedleOutline().stroke(Theme.Color.gold, lineWidth: 1.5)
        }.frame(width: side * 0.14, height: side * 0.70)
    }
}

/// Геометрическая арабеска-гравировка. Векторная, без текста и изображений святынь.
private struct QiblaArabesque: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        func point(_ angle: Double, _ fraction: CGFloat) -> CGPoint {
            CGPoint(x: center.x + cos(angle) * radius * fraction,
                    y: center.y + sin(angle) * radius * fraction)
        }
        for index in 0..<16 {
            let angle = Double(index) * .pi / 8
            path.move(to: center)
            path.addQuadCurve(to: point(angle, 1), control: point(angle - .pi / 4, 0.70))
            path.addQuadCurve(to: center, control: point(angle + .pi / 4, 0.70))
        }
        for fraction in [0.40, 0.72, 0.98] {
            for index in 0..<16 {
                let angle = Double(index) * .pi / 8
                let p = point(angle, fraction)
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
        return path
    }
}

private struct QiblaNeedleHalf: Shape {
    var left: Bool
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: 0))
            p.addLine(to: CGPoint(x: left ? rect.minX : rect.maxX, y: rect.height * 0.52))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.43))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
private struct QiblaNeedleOutline: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: 0))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.height * 0.52))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.43))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.height * 0.52))
            p.closeSubpath()
        }
    }
}
