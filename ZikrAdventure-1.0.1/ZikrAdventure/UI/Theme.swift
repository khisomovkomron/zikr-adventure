// Theme.swift
// Дизайн-токены SwiftUI. Источник истины — CSS :root / тёмная тема в index.html
// и таблица токенов Confluence «UI kit — правила». Размеры не хардкодятся в экранах.

import SwiftUI
import UIKit

enum Theme {

    // MARK: - Color

    /// Имена ассетов совпадают с CSS-переменными, кроме уже существующих
    /// LaunchBackground (--bg) и AccentColor (--accent).
    enum Color {
        static let bg = SwiftUI.Color("LaunchBackground")
        static let bgSubtle = SwiftUI.Color("Bg2")
        static let surface = SwiftUI.Color("Surface")
        static let surfaceRaised = SwiftUI.Color("Surface2")
        static let text = SwiftUI.Color("Text")
        static let textSecondary = SwiftUI.Color("Text2")
        static let textDisabled = SwiftUI.Color("Disabled")
        static let textOnPrimary = SwiftUI.Color("TextOnPrimary")
        static let primary = SwiftUI.Color("Navy")
        static let accent = SwiftUI.Color("AccentColor")
        static let accentSoft = SwiftUI.Color("AccentSoft")
        static let gold = SwiftUI.Color("Gold")
        static let goldLight = SwiftUI.Color("GoldLight")
        static let border = SwiftUI.Color("Border")
        static let divider = SwiftUI.Color("Divider")
        static let danger = SwiftUI.Color("Danger")
        static let success = SwiftUI.Color("Positive")
        static let warning = SwiftUI.Color("Warning")
        static let locked = SwiftUI.Color("Locked")
        static let scrim = SwiftUI.Color("Scrim")
        static let mapSea = SwiftUI.Color("Sea")
        static let mapLand = SwiftUI.Color("Land")
        static let mapCountry = SwiftUI.Color("Country")
        static let mapBorder = SwiftUI.Color("Border")
        static let mapMount = SwiftUI.Color("Mount")
        static let shadow = SwiftUI.Color("Shadow")
        static let overlayShadow = SwiftUI.Color("OverlayShadow")
        static let floatingShadow = SwiftUI.Color("FloatingShadow")
        static let zikrButtonShadow = SwiftUI.Color("ZikrButtonShadow")
        static let knobShadow = SwiftUI.Color("KnobShadow")
    }

    // MARK: - Opacity (CSS hex alpha, не «на глаз»)

    enum Opacity {
        /// `.btn.primary` border-color: #C2A05A88
        static let primaryBorder: CGFloat = 0x88 / 255.0
        /// `.banner` / `.tl.on` accent mix ~45–50%
        static let accentBorder: CGFloat = 0.45
        /// `.badge` / `.sira` accent fill ~10–12%
        static let accentFill: CGFloat = 0.10
        /// `.badge.warn` warning fill 10%
        static let warningFill: CGFloat = 0.10
        /// Pressed button (нет отдельного токена в CSS; лёгкое затемнение)
        static let pressed: CGFloat = 0.88
    }

    // MARK: - Space  (space.1 … space.8)

    enum Space {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s5: CGFloat = 20
        static let s6: CGFloat = 24
        static let s8: CGFloat = 32
        /// CSS padding 10 / 14 — не входят в 4-pt шкалу, но заданы в index.html.
        static let buttonY: CGFloat = 10
        static let controlX: CGFloat = 14
        static let groupHeaderTop: CGFloat = 22
        static let sectionTitleBottom: CGFloat = 6
    }

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let button: CGFloat = 14
        static let list: CGFloat = 16
        static let card: CGFloat = 18
        static let sheet: CGFloat = 22
        static let chipButton: CGFloat = 10
        static let toggle: CGFloat = 31
        static let pill: CGFloat = 999
    }

    // MARK: - Size

    enum Size {
        static let iconSm: CGFloat = 16
        static let iconMd: CGFloat = 20
        static let iconButton: CGFloat = 19
        static let iconList: CGFloat = 22
        static let iconTab: CGFloat = 23
        static let iconLg: CGFloat = 24
        static let iconXl: CGFloat = 28
        static let iconColumn: CGFloat = 26
        static let touch: CGFloat = 44
        static let button: CGFloat = 48
        static let chip: CGFloat = 40
        static let chipColumns: Int = 3
        static let row: CGFloat = 48
        static let toggleRow: CGFloat = 52
        static let toggleWidth: CGFloat = 51
        static let toggleHeight: CGFloat = 31
        static let toggleKnob: CGFloat = 27
        static let toggleKnobInset: CGFloat = 2
        static let toggleTravel: CGFloat = 20
        static let progress: CGFloat = 8
        static let hairline: CGFloat = 1
        static let tabBar: CGFloat = 49
        static let tabBarTopPadding: CGFloat = 4
        static let tabGap: CGFloat = 2
        static let grabWidth: CGFloat = 40
        static let grabHeight: CGFloat = 5
        static let focusRing: CGFloat = 3
        static let focusRingOffset: CGFloat = 2
    }

    // MARK: - Typography

    /// Шкала из CSS / Figma. Dynamic Type через UIFontMetrics.
    enum Typo {
        case displayCounter
        case headingXL
        case headingLG
        case headingMD
        case headingSM
        case headingXS
        case translit
        case body
        case bodyStrong
        case callout
        case calloutMedium
        case footnote
        case caption
        case tab
        case tabSelected
        case arabic
        case sectionTitle
        case kicker

        var pointSize: CGFloat {
            switch self {
            case .displayCounter: return 72
            case .headingXL: return 26
            case .headingLG: return 22
            case .headingMD: return 20
            case .headingSM: return 19
            case .headingXS: return 15
            // .group-h / .ch-title in CSS are 19; Confluence heading.sm listed 18.
            case .translit: return 21
            case .body, .bodyStrong: return 17
            case .callout, .calloutMedium: return 15
            case .footnote: return 14
            case .caption: return 13
            case .tab, .tabSelected: return 12
            case .arabic: return 44
            case .sectionTitle: return 15
            case .kicker: return 13.5
            }
        }

        var weight: UIFont.Weight {
            switch self {
            case .displayCounter, .headingXL, .headingLG, .headingMD,
                 .headingSM, .headingXS, .sectionTitle:
                return .semibold
            case .bodyStrong, .tabSelected, .calloutMedium:
                return .bold
            case .callout, .kicker:
                return .medium
            case .translit, .body, .footnote, .caption, .arabic, .tab:
                return .regular
            }
        }

        var design: UIFontDescriptor.SystemDesign {
            switch self {
            case .displayCounter, .headingXL, .headingLG, .headingMD,
                 .headingSM, .headingXS, .translit, .sectionTitle, .arabic:
                return .serif
            default:
                return .default
            }
        }

        var textStyle: UIFont.TextStyle {
            switch self {
            case .displayCounter, .arabic: return .largeTitle
            case .headingXL: return .title1
            case .headingLG: return .title2
            case .headingMD: return .title3
            case .headingSM: return .headline
            case .headingXS, .sectionTitle: return .subheadline
            case .translit: return .title3
            case .body, .bodyStrong: return .body
            case .callout, .calloutMedium: return .callout
            case .footnote, .kicker: return .footnote
            case .caption: return .caption1
            case .tab, .tabSelected: return .caption2
            }
        }

        var italic: Bool {
            self == .translit
        }

        var usesArabicFamily: Bool {
            self == .arabic
        }
    }

    enum Font {
        /// line-height: 1.45 у body в CSS
        static let bodyLineHeightMultiple: CGFloat = 1.45

        static func ui(_ typo: Typo, sizeCategory: ContentSizeCategory) -> SwiftUI.Font {
            _ = sizeCategory
            return SwiftUI.Font(scaledUIFont(typo))
        }

        static func scaledUIFont(_ typo: Typo) -> UIFont {
            let size = typo.pointSize
            let font: UIFont
            if typo.usesArabicFamily, let geeza = UIFont(name: "GeezaPro", size: size) {
                font = geeza
            } else {
                let base = UIFont.systemFont(ofSize: size, weight: typo.weight)
                var descriptor = base.fontDescriptor
                if let designed = descriptor.withDesign(typo.design) {
                    descriptor = designed
                }
                if typo.italic,
                   let italic = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) {
                    descriptor = italic
                }
                font = UIFont(descriptor: descriptor, size: size)
            }
            return UIFontMetrics(forTextStyle: typo.textStyle).scaledFont(for: font)
        }
    }

    // MARK: - Shadow

    enum Shadow {
        enum Kind {
            case card
            case overlay
            case floating
            case zikrButton
            case knob
        }

        static func color(_ kind: Kind) -> SwiftUI.Color {
            switch kind {
            case .card: return Theme.Color.shadow
            case .overlay: return Theme.Color.overlayShadow
            case .floating: return Theme.Color.floatingShadow
            case .zikrButton: return Theme.Color.zikrButtonShadow
            case .knob: return Theme.Color.knobShadow
            }
        }

        static func radius(_ kind: Kind) -> CGFloat {
            switch kind {
            case .card: return 20
            case .overlay: return 30
            case .floating: return 10
            case .zikrButton: return 30
            case .knob: return 3
            }
        }

        static func yOffset(_ kind: Kind) -> CGFloat {
            switch kind {
            case .card: return 6
            case .overlay: return 12
            case .floating: return 3
            case .zikrButton: return 14
            case .knob: return 1
            }
        }
    }

    enum Motion {
        /// `.toggle span` transition .2s
        static let toggle: Double = 0.2
    }

    enum Scale {
        static let tabTitle: CGFloat = 0.7
        static let buttonTitle: CGFloat = 0.8
        static let counter: CGFloat = 0.5
    }
}

// MARK: - View helpers

private struct ThemeFontModifier: ViewModifier {
    @Environment(\.sizeCategory) private var sizeCategory
    let typo: Theme.Typo

    func body(content: Content) -> some View {
        content.font(Theme.Font.ui(typo, sizeCategory: sizeCategory))
    }
}

private struct ThemeShadowModifier: ViewModifier {
    let kind: Theme.Shadow.Kind

    func body(content: Content) -> some View {
        content.shadow(
            color: Theme.Shadow.color(kind),
            radius: Theme.Shadow.radius(kind),
            x: 0,
            y: Theme.Shadow.yOffset(kind)
        )
    }
}

extension View {
    func themeFont(_ typo: Theme.Typo) -> some View {
        modifier(ThemeFontModifier(typo: typo))
    }

    func themeShadow(_ kind: Theme.Shadow.Kind) -> some View {
        modifier(ThemeShadowModifier(kind: kind))
    }
}

/// Light + Dark PreviewProvider helper (iOS 16, без Preview-макроса).
enum ThemePreview {
    @ViewBuilder
    static func pair<Content: View>(name: String, @ViewBuilder content: () -> Content) -> some View {
        content()
            .preferredColorScheme(.light)
            .previewDisplayName("\(name) · Light")
        content()
            .preferredColorScheme(.dark)
            .previewDisplayName("\(name) · Dark")
    }
}
