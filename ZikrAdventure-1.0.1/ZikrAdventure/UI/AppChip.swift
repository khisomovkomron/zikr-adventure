// AppChip.swift
// Чипы языка .lang / .lang.on. Сегментированного контроля в вебе нет — это его аналог.
// Шрифт как у body: 17 pt medium. Перенос — Layout (iOS 16), как flex-wrap.

import SwiftUI

struct AppChip: View {
    let title: String
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .themeFont(.chip)
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
        AppChipFlowLayout(spacing: Theme.Space.s2) {
            ForEach(items, id: \.self) { item in
                AppChip(title: item, isSelected: item == selected) {
                    selected = item
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

/// flex-wrap для чипов. `Layout` доступен с iOS 16, без ViewThatFits и без сетки из N колонок.
private struct AppChipFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(in: bounds.width, subviews: subviews)
        for index in subviews.indices {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + result.origins[index].x, y: bounds.minY + result.origins[index].y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrange(
        in maxWidth: CGFloat?,
        subviews: Subviews
    ) -> (size: CGSize, origins: [CGPoint], sizes: [CGSize]) {
        let limit = maxWidth ?? CGFloat.greatestFiniteMagnitude
        var origins: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > limit {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        let height = subviews.isEmpty ? 0 : y + rowHeight
        let width = maxWidth ?? maxX
        return (CGSize(width: width, height: height), origins, sizes)
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
