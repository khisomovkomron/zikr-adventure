// AppSectionHeader.swift
// Заголовки .section-title и .group-h.

import SwiftUI

struct AppSectionHeader: View {
    enum Style {
        case sectionTitle
        case group
    }

    let title: String
    var style: Style = .group

    var body: some View {
        Text(title)
            .themeFont(style == .group ? .headingSM : .sectionTitle)
            .foregroundColor(style == .group ? Theme.Color.text : Theme.Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, style == .group ? Theme.Space.groupHeaderTop : 0)
            .padding(.bottom, style == .group ? Theme.Space.s2 : Theme.Space.sectionTitleBottom)
            .padding(.horizontal, style == .group ? Theme.Space.s1 : 0)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(title)
    }
}

struct AppSectionHeader_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "AppSectionHeader") {
            VStack(alignment: .leading, spacing: 0) {
                AppSectionHeader(title: "Звук и вибрация", style: .group)
                AppSectionHeader(title: "Отображение", style: .sectionTitle)
            }
            .padding(Theme.Space.s4)
            .background(Theme.Color.bg)
        }
    }
}
