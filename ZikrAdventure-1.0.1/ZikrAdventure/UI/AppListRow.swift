// AppListRow.swift
// Список .list / строки .li и .switch из настроек и Инфо.

import SwiftUI

struct AppList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        // `border: 1px` у `.list` занимает место в раскладке CSS.
        .padding(Theme.Size.hairline)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.list, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.list, style: .continuous)
                .strokeBorder(Theme.Color.divider, lineWidth: Theme.Size.hairline)
        )
        .accessibilityElement(children: .contain)
    }
}

struct AppListRow: View {
    enum Kind {
        case plain
        case icon
        case link
        case destructive
        case value
    }

    let title: String
    var subtitle: String? = nil
    var kind: Kind = .plain
    var icon: Image? = nil
    var value: String? = nil
    var showsTopDivider: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        rowButton
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabelText)
            .accessibilityAddTraits(traits)
    }

    @ViewBuilder
    private var rowButton: some View {
        if let action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: Theme.Space.s3) {
            if let icon {
                icon
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.Size.iconList, height: Theme.Size.iconList)
                    .frame(width: Theme.Size.iconColumn, alignment: .top)
                    .foregroundColor(iconColor)
                    .padding(.top, Theme.Size.hairline)
                    .frame(minHeight: Theme.Size.iconListLineBox, alignment: .top)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: Theme.Space.s1) {
                Text(title)
                    .themeFont(.body)
                    .themeLineHeight(.body, multiple: Theme.Font.bodyLineHeightMultiple)
                    .foregroundColor(titleColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let subtitle {
                    Text(subtitle)
                        .themeFont(.footnote)
                        .foregroundColor(Theme.Color.textSecondary)
                        .multilineTextAlignment(.leading)
                }
            }

            if let value {
                Text(value)
                    .themeFont(.body)
                    .foregroundColor(Theme.Color.textSecondary)
                    .accessibilityHidden(true)
            }

            if kind == .link {
                Image(systemName: "chevron.right")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.Size.iconSm, height: Theme.Size.iconSm)
                    .foregroundColor(Theme.Color.accent)
                    .padding(.top, Theme.Space.s1)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Theme.Space.controlX)
        .padding(.vertical, Theme.Space.s3)
        // `border-top: 1px` у `.li` занимает место в раскладке (у первой строки его нет).
        .padding(.top, showsTopDivider ? Theme.Size.hairline : 0)
        .frame(minHeight: Theme.Size.row, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface)
        .overlay(alignment: .top) {
            if showsTopDivider {
                Theme.Color.divider.frame(height: Theme.Size.hairline)
            }
        }
        .contentShape(Rectangle())
    }

    private var titleColor: Color {
        switch kind {
        case .destructive: return Theme.Color.danger
        case .link: return Theme.Color.accent
        default: return Theme.Color.text
        }
    }

    private var iconColor: Color {
        kind == .destructive ? Theme.Color.danger : Theme.Color.accent
    }

    private var accessibilityLabelText: String {
        var parts = [title]
        if let subtitle { parts.append(subtitle) }
        if let value { parts.append(value) }
        return parts.joined(separator: ", ")
    }

    private var traits: AccessibilityTraits {
        var result: AccessibilityTraits = []
        if action != nil {
            result.formUnion(.isButton)
        }
        if kind == .link {
            result.formUnion(.isLink)
        }
        return result
    }
}

struct AppListRow_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "AppListRow") {
            AppList {
                AppListRow(title: "О приложении", kind: .icon, icon: Image(systemName: "info.circle"), showsTopDivider: false, action: {})
                AppListRow(title: "Конфиденциальность", kind: .link, action: {})
                AppListRow(title: "Язык", kind: .value, value: "Русский")
                AppListRow(title: "Сбросить весь прогресс", kind: .destructive, action: {})
            }
            .padding(Theme.Space.s4)
            .background(Theme.Color.bg)
        }
    }
}
