// AppToggle.swift
// Переключатель .toggle (51×31, --positive / --divider) и строка .switch.

import SwiftUI

struct AppToggle: View {
    @Binding var isOn: Bool
    var label: String
    var onValue: String = "Вкл."
    var offValue: String = "Выкл."

    var body: some View {
        Button(action: { isOn.toggle() }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(width: Theme.Size.toggleWidth, height: Theme.Size.toggleHeight)

                Circle()
                    .fill(Theme.Color.textOnPrimary)
                    .frame(width: Theme.Size.toggleKnob, height: Theme.Size.toggleKnob)
                    .themeShadow(.knob)
                    .padding(Theme.Size.toggleKnobInset)
            }
            .animation(.easeInOut(duration: Theme.Motion.toggle), value: isOn)
        }
        .buttonStyle(.plain)
        .frame(width: Theme.Size.toggleWidth, height: Theme.Size.toggleHeight)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? onValue : offValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityRemoveTraits(isOn ? [] : .isSelected)
        .accessibilityHint(isOn ? offValue : onValue)
    }

    private var trackColor: Color {
        isOn ? Theme.Color.success : Theme.Color.divider
    }
}

struct AppToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var showsTopDivider: Bool = true
    var onValue: String = "Вкл."
    var offValue: String = "Выкл."

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.s3) {
            Text(title)
                .themeFont(.body)
                .foregroundColor(Theme.Color.text)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            AppToggle(isOn: $isOn, label: title, onValue: onValue, offValue: offValue)
        }
        .padding(.horizontal, Theme.Space.controlX)
        .padding(.vertical, Theme.Space.s3)
        .frame(minHeight: Theme.Size.toggleRow)
        .background(Theme.Color.surface)
        .overlay(alignment: .top) {
            if showsTopDivider {
                Theme.Color.divider.frame(height: Theme.Size.hairline)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct AppToggle_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "AppToggle") {
            TogglePreviewHost()
                .padding(Theme.Space.s4)
                .background(Theme.Color.bg)
        }
    }

    private struct TogglePreviewHost: View {
        @State private var haptics = true
        @State private var sound = false

        var body: some View {
            AppList {
                AppToggleRow(title: "Вибрация", isOn: $haptics, showsTopDivider: false)
                AppToggleRow(title: "Звук", isOn: $sound)
            }
        }
    }
}
