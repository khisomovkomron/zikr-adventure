// AppProgressBar.swift
// Полоса прогресса .bar / .bar > i.

import SwiftUI

struct AppProgressBar: View {
    var progress: Double
    var label: String

    private var clamped: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.Color.accentSoft)
                Capsule()
                    .fill(Theme.Color.accent)
                    .frame(width: geo.size.width * clamped)
            }
        }
        .frame(height: Theme.Size.progress)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(percentLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var percentLabel: String {
        "\(Int((clamped * 100).rounded()))%"
    }
}

struct AppProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "AppProgressBar") {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                AppProgressBar(progress: 0.35, label: "Личная цель")
                AppProgressBar(progress: 1, label: "Уровень завершён")
            }
            .padding(Theme.Space.s4)
            .background(Theme.Color.bg)
        }
    }
}
