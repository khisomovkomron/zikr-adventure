// AppChip.swift
// Чипы языка .lang / .lang.on. Сегментированного контроля в вебе нет — это его аналог.

import SwiftUI

struct AppChip: View {
    let title: String
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .themeFont(.callout)
                .foregroundColor(isSelected ? Theme.Color.textOnPrimary : Theme.Color.text)
                .padding(.horizontal, Theme.Space.controlX)
                .padding(.vertical, Theme.Space.s2)
                .frame(minHeight: Theme.Size.chip)
                .background(isSelected ? Theme.Color.primary : Theme.Color.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(border, lineWidth: Theme.Size.hairline)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityRemoveTraits(isSelected ? [] : .isSelected)
    }

    private var border: Color {
        isSelected ? Theme.Color.gold : Theme.Color.divider
    }
}

struct AppChipGroup: View {
    let items: [String]
    @Binding var selected: String

    var body: some View {
        FlexibleChipWrap(items: items, selected: $selected)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Язык")
    }
}

/// Простая переносимая сетка чипов без iOS 17 Layout API.
private struct FlexibleChipWrap: View {
    let items: [String]
    @Binding var selected: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s2) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: Theme.Space.s2) {
                    ForEach(row, id: \.self) { item in
                        AppChip(title: item, isSelected: item == selected) {
                            selected = item
                        }
                    }
                }
            }
        }
    }

    private var rows: [[String]] {
        var result: [[String]] = []
        var current: [String] = []
        for item in items {
            current.append(item)
            if current.count == Theme.Size.chipColumns {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

struct AppChip_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "AppChip") {
            ChipPreviewHost()
                .padding(Theme.Space.s4)
                .background(Theme.Color.bg)
        }
    }

    private struct ChipPreviewHost: View {
        @State private var selected = "Русский"

        var body: some View {
            AppChipGroup(
                items: ["Русский", "English", "O‘zbekcha", "Тоҷикӣ", "Қазақша", "Кыргызча"],
                selected: $selected
            )
        }
    }
}
