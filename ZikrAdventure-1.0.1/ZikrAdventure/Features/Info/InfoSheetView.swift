// InfoSheetView.swift
// ZKR-48: лист `.scrim` / `.sheet` из openSheet() в index.html — тема «Инфо» и «Легенда» (openLegend()).
// Появление: затемнение fade .2s, лист up .26s (40 pt); закрытие мгновенное, как closeSheet().
// Закрывают: нажатие на затемнение, кнопка «Закрыть», жест VoiceOver «escape».

import SwiftUI
import ZikrContent

struct InfoSheetHost: View {
    let sheet: InfoSheet
    let page: InfoPage
    let topic: (InfoTopicID) -> InfoTopic?
    let animationsEnabled: Bool
    let close: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var isShown = false
    @State private var contentHeight: CGFloat = 0
    @AccessibilityFocusState private var isTitleFocused: Bool

    /// motionReduced() в index.html: системный Reduce Motion или выключенные «Анимации».
    private var reducesMotion: Bool { systemReduceMotion || !animationsEnabled }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Theme.Color.sheetScrim
                    .ignoresSafeArea()
                    .opacity(isShown ? 1 : 0)
                    .animation(reducesMotion ? nil : Self.ease(Theme.Motion.scrimFade), value: isShown)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("info.scrim")

                // 86% от высоты веб-вью, а она заходит под верхнюю safe area.
                sheetBody(maxHeight: (proxy.size.height + proxy.safeAreaInsets.top) * Theme.Scale.sheetMaxHeight)
                    .frame(maxWidth: .infinity)
                    .background(
                        Theme.Color.bg
                            .clipShape(TopRoundedRectangle(radius: Theme.Radius.sheet))
                            .ignoresSafeArea(edges: .bottom)
                    )
                    .offset(y: isShown ? 0 : Theme.Motion.sheetUpOffset)
                    .animation(reducesMotion ? nil : Self.ease(Theme.Motion.sheetUp), value: isShown)
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape, close)
                    .accessibilityIdentifier("info.sheet")
            }
        }
        .onAppear(perform: present)
    }

    /// `.sheet` max-height 86% + overflow-y auto: высота по содержимому, прокрутка — только если не влезает.
    private func sheetBody(maxHeight: CGFloat) -> some View {
        ScrollView {
            sheetContent
                .background(
                    GeometryReader { content in
                        SwiftUI.Color.clear.preference(key: SheetContentHeightKey.self, value: content.size.height)
                    }
                )
        }
        .scrollDisabled(contentHeight <= maxHeight)
        .frame(height: min(contentHeight, maxHeight))
        .onPreferenceChange(SheetContentHeightKey.self) { contentHeight = $0 }
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Theme.Color.divider)
                .frame(width: Theme.Size.grabWidth, height: Theme.Size.grabHeight)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.grab))
                .frame(maxWidth: .infinity)
                .padding(.bottom, Theme.Space.s3)
                .accessibilityHidden(true)

            switch sheet {
            case .topic(let id):
                if let topic = topic(id) {
                    topicContent(topic)
                }
            case .legend:
                legendContent(page.legend)
            }
        }
        .padding(.top, Theme.Space.sheetTop)
        .padding(.horizontal, Theme.Space.sheetX)
        .padding(.bottom, Theme.Space.s6)
    }

    /// `<h2 class="hp-title">` + `<p>` + `.btn.full[data-close]`.
    private func topicContent(_ topic: InfoTopic) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            title(topic.title)
            Text(topic.body)
                .themeFont(.body)
                .themeLineHeight(.body, multiple: Theme.Font.bodyLineHeightMultiple)
                .foregroundColor(Theme.Color.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, Theme.Typo.body.pointSize)
                .accessibilityIdentifier("info.sheet.body")
            closeButton
        }
    }

    /// openLegend(): заголовок, `.demo` с дисклеймером, список значков, «Закрыть».
    private func legendContent(_ legend: InfoLegend) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            title(legend.title)
            Text(legend.disclaimer)
                .themeFont(.callout)
                .themeLineHeight(.callout, multiple: Theme.Font.bodyLineHeightMultiple)
                .foregroundColor(Theme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, Theme.Space.noteY)
                .padding(.horizontal, Theme.Space.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Color.bgSubtle)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .padding(.top, Theme.Space.buttonY)
            AppList {
                ForEach(Array(legend.entries.enumerated()), id: \.element.id) { index, entry in
                    AppListRow(
                        title: entry.text,
                        kind: .icon,
                        icon: entry.icon.image,
                        showsTopDivider: index > 0
                    )
                }
            }
            .padding(.top, Theme.Space.s3)
            closeButton
                .padding(.top, Theme.Space.sheetButtonTop)
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .themeFont(.headingSheet)
            .themeLineHeight(.headingSheet, multiple: Theme.Font.sheetTitleLineHeightMultiple)
            .foregroundColor(Theme.Color.text)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($isTitleFocused)
            .accessibilityIdentifier("info.sheet.title")
    }

    private var closeButton: some View {
        AppButton(title: page.closeTitle, kind: .secondary, action: close)
            .accessibilityIdentifier("info.sheet.close")
    }

    private func present() {
        isShown = true
        DispatchQueue.main.async {
            isTitleFocused = true
        }
    }

    /// CSS `ease` = cubic-bezier(.25, .1, .25, 1).
    private static func ease(_ duration: Double) -> Animation {
        .timingCurve(0.25, 0.1, 0.25, 1, duration: duration)
    }
}

private struct SheetContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Скругление только сверху: border-radius 22px 22px 0 0 (iOS 16 — без UnevenRoundedRectangle).
private struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: radius, height: radius)
            ).cgPath
        )
    }
}

struct InfoSheetHost_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "InfoSheet · legend") {
            InfoSheetPreviewHost(sheet: .legend)
        }
        ThemePreview.pair(name: "InfoSheet · about") {
            InfoSheetPreviewHost(sheet: .topic(.about))
        }
    }

    private struct InfoSheetPreviewHost: View {
        let sheet: InfoSheet
        @StateObject private var viewModel = InfoViewModel(
            provider: BundledInfoContentProvider(),
            settings: nil,
            language: "ru"
        )

        var body: some View {
            InfoView(viewModel: viewModel)
                .onAppear { viewModel.open(sheet) }
        }
    }
}
