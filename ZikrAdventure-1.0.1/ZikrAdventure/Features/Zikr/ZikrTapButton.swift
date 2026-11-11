// ZikrTapButton.swift
// ZKR-52: большая кнопка зикра `.zikr-btn` и ripple-анимация (index.html).
// Размер min(58vw, 210), градиент #2E4470 → #18263F, золотое кольцо (inset 7, 2 pt), тень zikrButton.
// Нажатие: scale .965 + яркость, .12 с. Ripple .55 с — только если движение не уменьшено
// (системный Reduce Motion или выключенные «Анимации», как motionReduced()).

import SwiftUI

struct ZikrTapButton: View {
    let title: String
    let accessibilityText: String
    /// Растёт на каждое нажатие (ZikrViewModel.tapCount).
    let tapCount: Int
    let animationsEnabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.sizeCategory) private var sizeCategory
    @State private var ripples: [Int] = []

    private var reducesMotion: Bool { systemReduceMotion || !animationsEnabled }

    var body: some View {
        let size = Theme.Zikr.buttonSize(width: Theme.Size.viewportWidth)
        let labelWidth = max(0, size - 2 * (Theme.Zikr.innerPadding + Theme.Zikr.buttonUAPadding))
        let labelFont = Theme.Font.scaledUIFont(.bodyStrong, sizeCategory: sizeCategory)
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: Theme.Color.zikrButtonTop, location: 0),
                                .init(color: Theme.Color.zikrButtonBottom, location: Theme.Zikr.gradientStop),
                            ]),
                            center: UnitPoint(x: Theme.Zikr.gradientCenterX, y: Theme.Zikr.gradientCenterY),
                            startRadius: 0,
                            endRadius: size * Self.farthestCorner
                        )
                    )
                Circle()
                    .strokeBorder(Theme.Color.gold, lineWidth: Theme.Zikr.ringWidth)
                    .padding(Theme.Zikr.ringInset)
                VStack(spacing: Theme.Zikr.innerGap) {
                    Image("InfoHand")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Theme.Zikr.handIcon, height: Theme.Zikr.handIcon)
                        .accessibilityHidden(true)
                    Text(Self.greedyLines(title, font: labelFont, width: labelWidth))
                        .themeFont(.bodyStrong)
                        .themeLineHeight(.bodyStrong, multiple: Theme.Font.bodyLineHeightMultiple)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(Theme.Scale.buttonTitle)
                        // Ширина строки как в WebKit: .inner padding 20 + padding <button> по умолчанию 6.
                        .frame(maxWidth: labelWidth)
                }
                .foregroundColor(Theme.Color.textOnPrimary)
                .padding(.vertical, Theme.Zikr.innerPadding)
                ForEach(ripples, id: \.self) { id in
                    ZikrRipple()
                        .id(id)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(ZikrPressStyle(animated: !reducesMotion))
        .themeShadow(.zikrButton)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("zikr.button")
        .onChange(of: tapCount) { _ in
            guard !reducesMotion else { return }
            let id = tapCount
            ripples.append(id)
            DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Zikr.rippleDuration + 0.05) {
                ripples.removeAll { $0 == id }
            }
        }
    }

    /// CSS radial-gradient без размера = farthest-corner: от (35%, 30%) до (100%, 100%).
    private static let farthestCorner: CGFloat = {
        let dx = 1 - Theme.Zikr.gradientCenterX, dy = 1 - Theme.Zikr.gradientCenterY
        return (dx * dx + dy * dy).squareRoot()
    }()

    /// Перенос строк как в WebKit: жадно, слово за словом. Системный перенос iOS не оставляет одно слово
    /// на последней строке («Нажмите / для зикра»), а веб показывает «Нажмите для / зикра».
    static func greedyLines(_ text: String, font: UIFont, width: CGFloat) -> String {
        guard width > 0 else { return text }
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        func measure(_ s: String) -> CGFloat { (s as NSString).size(withAttributes: attributes).width }
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: true).map(String.init) {
            let candidate = current.isEmpty ? word : current + " " + word
            if current.isEmpty || measure(candidate) <= width {
                current = candidate
            } else {
                lines.append(current)
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.joined(separator: "\n")
    }
}

private struct ZikrPressStyle: ButtonStyle {
    let animated: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Theme.Zikr.pressScale : 1)
            .brightness(configuration.isPressed ? Theme.Zikr.pressBrightness : 0)
            .animation(animated ? .easeInOut(duration: Theme.Zikr.pressDuration) : nil, value: configuration.isPressed)
    }
}

/// `.ripple`: золотое кольцо, opacity .6 → 0, scale 1 → 1.18 за .55 с ease-out.
private struct ZikrRipple: View {
    @State private var expanded = false

    var body: some View {
        Circle()
            .strokeBorder(Theme.Color.gold, lineWidth: Theme.Zikr.ringWidth)
            .scaleEffect(expanded ? Theme.Zikr.rippleScale : 1)
            .opacity(expanded ? 0 : Theme.Zikr.rippleOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: Theme.Zikr.rippleDuration)) { expanded = true }
            }
    }
}
