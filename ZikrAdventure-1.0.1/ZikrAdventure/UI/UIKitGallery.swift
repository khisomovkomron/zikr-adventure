// UIKitGallery.swift
// Внутренний каталог UI kit. Компилируется и открывается только в DEBUG.
// Release-сборка не содержит этого экрана.

#if DEBUG
import SwiftUI

struct UIKitGallery: View {
    @Environment(\.dismiss) private var dismiss
    @State private var toggleOn = true
    @State private var toggleOff = false
    @State private var language = "Русский"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.s6) {
                    buttonsSection
                    chipsSection
                    cardsSection
                    listSection
                    toggleSection
                    headersSection
                    metersSection
                    linksSection
                    iconButtonsSection
                }
                .padding(.horizontal, Theme.Space.s4)
                .padding(.vertical, Theme.Space.s5)
            }
            .background(Theme.Color.bg.ignoresSafeArea())
            .navigationTitle("UI kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .tint(Theme.Color.accent)
    }

    private var buttonsSection: some View {
        gallerySection("Кнопки · .btn") {
            AppButton(title: "Primary · Начать", kind: .primary, action: {})
            AppButton(title: "Secondary · Закрыть", kind: .secondary, action: {})
            AppButton(title: "Destructive · Сбросить", kind: .destructive, action: {})
            AppButton(title: "Disabled", kind: .secondary, action: {}).disabled(true)
        }
    }

    private var chipsSection: some View {
        gallerySection("Чипы языка · .lang (сегмента в вебе нет)") {
            AppChipGroup(
                items: ["Русский", "English", "O‘zbekcha", "Тоҷикӣ", "Қазақша", "Кыргызча"],
                selected: $language
            )
        }
    }

    private var cardsSection: some View {
        gallerySection("Карточка · .card") {
            AppCard {
                VStack(alignment: .leading, spacing: Theme.Space.s2) {
                    Text("Сегодня")
                        .themeFont(.headingSM)
                        .foregroundColor(Theme.Color.text)
                    Text("142")
                        .themeFont(.headingLG)
                        .foregroundColor(Theme.Color.text)
                    Text("повторений сегодня")
                        .themeFont(.footnote)
                        .foregroundColor(Theme.Color.textSecondary)
                }
            }
        }
    }

    private var listSection: some View {
        gallerySection("Список · .list / .li") {
            AppList {
                AppListRow(
                    title: "О приложении",
                    kind: .icon,
                    icon: Image(systemName: "info.circle"),
                    showsTopDivider: false,
                    action: {}
                )
                AppListRow(title: "Конфиденциальность", kind: .link, action: {})
                AppListRow(title: "Язык", kind: .value, value: language)
                AppListRow(title: "Сбросить весь прогресс", kind: .destructive, action: {})
            }
        }
    }

    private var toggleSection: some View {
        gallerySection("Переключатели · .toggle / .switch") {
            AppList {
                AppToggleRow(title: "Вибрация", isOn: $toggleOn, showsTopDivider: false)
                AppToggleRow(title: "Звук", isOn: $toggleOff)
            }
        }
    }

    private var headersSection: some View {
        gallerySection("Заголовки · .group-h / .section-title") {
            AppSectionHeader(title: "Звук и вибрация", style: .group)
            AppSectionHeader(title: "Отображение", style: .sectionTitle)
            AppFootnote(text: "Цель необязательна. Пропустить день — нормально, ничего не теряется.")
        }
    }

    private var metersSection: some View {
        gallerySection("Счётчик и прогресс · .counter / .bar") {
            AppCounterDisplay(value: 12840, caption: "всего повторений")
            AppProgressBar(progress: 0.42, label: "Личная цель")
        }
    }

    private var linksSection: some View {
        gallerySection("Ссылка · a / .link") {
            AppLink(title: "Конфиденциальность", action: {})
        }
    }

    private var iconButtonsSection: some View {
        gallerySection("Иконка-кнопка · .icon-btn") {
            HStack(spacing: Theme.Space.s3) {
                AppIconButton(systemName: "chevron.left", label: "Назад", action: {})
                AppIconButton(systemName: "map", label: "Карта", action: {})
                AppIconButton(systemName: "gearshape", label: "Настройки", action: {})
            }
        }
    }

    private func gallerySection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s3) {
            Text(title)
                .themeFont(.sectionTitle)
                .foregroundColor(Theme.Color.textSecondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UIKitGallery_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "UIKitGallery") {
            UIKitGallery()
        }
    }
}
#endif
