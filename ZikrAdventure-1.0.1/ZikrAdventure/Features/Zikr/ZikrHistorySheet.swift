// ZikrHistorySheet.swift
// ZKR-52: лист «История по дням» — openHistory() в index.html: последние 30 дней (новые сверху),
// сноска, «Очистить историю» с подтверждением (confirmDialog) и «Закрыть». Пустая история — history.empty.
// Оформление листа — как InfoSheetHost (ZKR-48): затемнение .2 с, лист .26 с, 86 % высоты.

import SwiftUI

struct ZikrHistorySheet: View {
    @ObservedObject var viewModel: ZikrViewModel
    @ObservedObject var localization: LocalizationService

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var isShown = false
    @State private var contentHeight: CGFloat = 0
    @AccessibilityFocusState private var isTitleFocused: Bool

    init(viewModel: ZikrViewModel) {
        self.viewModel = viewModel
        self.localization = viewModel.localization
    }

    private var reducesMotion: Bool { systemReduceMotion || !viewModel.animationsEnabled }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Theme.Color.sheetScrim
                    .ignoresSafeArea()
                    .opacity(isShown ? 1 : 0)
                    .animation(reducesMotion ? nil : .easeInOut(duration: Theme.Motion.scrimFade), value: isShown)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.closeHistory() }
                    .accessibilityHidden(true)

                sheetBody(maxHeight: (proxy.size.height + proxy.safeAreaInsets.top) * Theme.Scale.sheetMaxHeight)
                    .frame(maxWidth: .infinity)
                    .background(
                        Theme.Color.bg
                            .clipShape(TopRoundedRectangle(radius: Theme.Radius.sheet))
                            .ignoresSafeArea(edges: .bottom)
                    )
                    .offset(y: isShown ? 0 : Theme.Motion.sheetUpOffset)
                    .animation(reducesMotion ? nil : .easeInOut(duration: Theme.Motion.sheetUp), value: isShown)
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { viewModel.closeHistory() }
                    .accessibilityIdentifier("zikr.history.sheet")
            }
        }
        .alert(tr(.historyConfirmT), isPresented: $viewModel.isClearHistoryConfirmPresented) {
            Button(tr(.commonCancel), role: .cancel) {}
            Button(tr(.historyClear), role: .destructive) { viewModel.confirmClearHistory() }
        } message: {
            Text(tr(.historyConfirmM))
        }
        .onAppear {
            isShown = true
            DispatchQueue.main.async { isTitleFocused = true }
        }
    }

    private func tr(_ key: L10nKey) -> String {
        localization.tr(key)
    }

    private func sheetBody(maxHeight: CGFloat) -> some View {
        ScrollView {
            sheetContent
                .background(
                    GeometryReader { content in
                        Color.clear.preference(key: SheetContentHeightKey.self, value: content.size.height)
                    }
                )
        }
        .scrollDisabled(contentHeight <= maxHeight)
        .frame(height: min(contentHeight, maxHeight))
        .onPreferenceChange(SheetContentHeightKey.self) { contentHeight = $0 }
    }

    private var sheetContent: some View {
        let days = viewModel.historyDays
        return VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Theme.Color.divider)
                .frame(width: Theme.Size.grabWidth, height: Theme.Size.grabHeight)
                .frame(maxWidth: .infinity)
                .padding(.bottom, Theme.Space.s3)
                .accessibilityHidden(true)

            Text(tr(.historyTitle))
                .themeFont(.headingSheet)
                .themeLineHeight(.headingSheet, multiple: Theme.Font.sheetTitleLineHeightMultiple)
                .foregroundColor(Theme.Color.text)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isTitleFocused)
                .accessibilityIdentifier("zikr.history.title")
                .padding(.bottom, Theme.Space.s1)

            if days.isEmpty {
                Text(tr(.historyEmpty))
                    .themeFont(.body)
                    .foregroundColor(Theme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Theme.Space.s3)
                    .accessibilityIdentifier("zikr.history.empty")
            } else {
                AppList {
                    ForEach(Array(days.enumerated()), id: \.element.day) { index, entry in
                        AppListRow(
                            title: Self.dateText(entry.day, locale: localization.locale),
                            kind: .value,
                            value: localization.format(Int(clamping: entry.count)),
                            showsTopDivider: index > 0
                        )
                        .accessibilityIdentifier("zikr.history.day.\(entry.day)")
                    }
                }
                AppFootnote(text: tr(.historyFoot))
                AppButton(title: tr(.historyClear), kind: .destructive) {
                    viewModel.requestClearHistory()
                }
                .padding(.top, Theme.Space.sheetButtonTop)
                .accessibilityIdentifier("zikr.history.clear")
            }

            AppButton(title: tr(.commonClose), kind: .secondary) {
                viewModel.closeHistory()
            }
            .padding(.top, Theme.Space.s3)
            .accessibilityIdentifier("zikr.history.close")
        }
        .padding(.top, Theme.Space.sheetTop)
        .padding(.horizontal, Theme.Space.sheetX)
        .padding(.bottom, Theme.Space.s6)
    }

    /// toLocaleDateString(locale(), { day: "numeric", month: "long", year: "numeric" }).
    static func dateText(_ key: String, locale: Locale) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return key }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return key }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMMMy")
        return formatter.string(from: date)
    }
}
