// InfoView.swift
// ZKR-48: нативный экран «Инфо» — повторяет renderInfo() из index.html:
// .topbar с заголовком вкладки, список из 4 тем и строки «Легенда»; тема открывает лист с текстом.

import SwiftUI
import ZikrContent

struct InfoView: View {
    @ObservedObject var viewModel: InfoViewModel

    var body: some View {
        ZStack {
            if let page = viewModel.page {
                InfoListScreen(page: page, open: viewModel.open)
                    .accessibilityHidden(viewModel.sheet != nil)
            }
            if let page = viewModel.page, let sheet = viewModel.sheet {
                InfoSheetHost(
                    sheet: sheet,
                    page: page,
                    topic: viewModel.topic,
                    animationsEnabled: viewModel.animationsEnabled,
                    close: viewModel.closeSheet
                )
                .id(sheet.id)
            }
        }
        .accessibilityIdentifier("info.screen")
    }
}

/// `#s-info`: `.topbar` + `.pad` со списком `.list`.
private struct InfoListScreen: View {
    let page: InfoPage
    let open: (InfoSheet) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(page.title)
                    .themeFont(.headingMD)
                    .foregroundColor(Theme.Color.text)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Theme.Space.topbarTop)
                    .padding(.bottom, Theme.Space.topbarBottom)
                    .padding(.horizontal, Theme.Space.s4)
                    .frame(maxWidth: .infinity, minHeight: Theme.Space.topbarMinHeight, alignment: .leading)

                AppList {
                    ForEach(Array(page.topics.enumerated()), id: \.element.id) { index, topic in
                        AppListRow(
                            title: topic.title,
                            kind: .icon,
                            icon: topic.icon.image,
                            showsTopDivider: index > 0,
                            action: { open(.topic(topic.id)) }
                        )
                        .accessibilityIdentifier("info.row.\(topic.id.rawValue)")
                    }
                    AppListRow(
                        title: page.legendRow.title,
                        kind: .icon,
                        icon: page.legendRow.icon.image,
                        action: { open(.legend) }
                    )
                    .accessibilityIdentifier("info.row.legend")
                }
                .padding(.top, Theme.Space.s1)
                .padding(.horizontal, Theme.Space.screenX)
                .padding(.bottom, Theme.Space.screenBottom)
            }
        }
        .background(Theme.Color.bg.ignoresSafeArea(edges: .top))
    }
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "InfoView") {
            InfoView(viewModel: InfoViewModel(
                provider: BundledInfoContentProvider(),
                settings: nil,
                language: "ru"
            ))
        }
    }
}
