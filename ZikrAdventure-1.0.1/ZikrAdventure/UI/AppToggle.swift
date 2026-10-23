// AppToggle.swift
// Переключатель .toggle (51×31, --positive / --divider) и строка .switch.
// Native Toggle + custom ToggleStyle: вся строка — контроль, VoiceOver читает switch.

import SwiftUI

struct AppToggle: View {
    @Binding var isOn: Bool
    var label: String
    var onValue: String = "Вкл."
    var offValue: String = "Выкл."

    var body: some View {
        Toggle(label, isOn: $isOn)
            .labelsHidden()
            .toggleStyle(AppSwitchToggleStyle())
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? onValue : offValue)
    }
}

struct AppToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var showsTopDivider: Bool = true
    var onValue: String = "Вкл."
    var offValue: String = "Выкл."

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .themeFont(.body)
                .foregroundColor(Theme.Color.text)
                .multilineTextAlignment(.leading)
                .accessibilityHidden(true)
        }
        .toggleStyle(AppToggleRowStyle())
        .background(Theme.Color.surface)
        .overlay(alignment: .top) {
            if showsTopDivider {
                Theme.Color.divider.frame(height: Theme.Size.hairline)
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? onValue : offValue)
    }
}

/// Только дорожка тумблера. Скрыта от VoiceOver — роль switch у Toggle.
private struct AppToggleTrack: View {
    var isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Theme.Color.success : Theme.Color.divider)
                .frame(width: Theme.Size.toggleWidth, height: Theme.Size.toggleHeight)

            Circle()
                .fill(Theme.Color.textOnPrimary)
                .frame(width: Theme.Size.toggleKnob, height: Theme.Size.toggleKnob)
                .themeShadow(.knob)
                .padding(Theme.Size.toggleKnobInset)
        }
        .animation(.easeInOut(duration: Theme.Motion.toggle), value: isOn)
        .frame(width: Theme.Size.toggleWidth, height: Theme.Size.toggleHeight)
        .accessibilityHidden(true)
    }
}

private struct AppSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        AppToggleTrack(isOn: configuration.isOn)
            .contentShape(Rectangle())
            .onTapGesture {
                configuration.isOn.toggle()
            }
            .accessibilityAction {
                configuration.isOn.toggle()
            }
    }
}

private struct AppToggleRowStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: Theme.Space.s3) {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
            AppToggleTrack(isOn: configuration.isOn)
        }
        .padding(.horizontal, Theme.Space.controlX)
        .padding(.vertical, Theme.Space.s3)
        .frame(minHeight: Theme.Size.toggleRow)
        .contentShape(Rectangle())
        .onTapGesture {
            configuration.isOn.toggle()
        }
        .accessibilityAction {
            configuration.isOn.toggle()
        }
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
