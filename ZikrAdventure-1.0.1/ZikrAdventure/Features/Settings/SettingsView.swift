// SettingsView.swift
// ZKR-50: нативный экран «Настройки» — порядок и состав как renderSettings() в index.html (IS_APP):
// заголовок → Аккаунт → Язык → Отклик → Движение → Отображение → Статистика → Сброс → сноска.
// Только вёрстка на UI kit (ZKR-51); логика — SettingsViewModel.

import SwiftUI
import ZikrDomain

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var localization: LocalizationService

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        self.localization = viewModel.localization
    }

    var body: some View {
        ScrollView {
            if let settings = viewModel.settings {
                content(settings)
            }
        }
        .background(Theme.Color.bg.ignoresSafeArea(edges: .top))
        .alert(
            viewModel.pendingConfirmation.map { tr($0.titleKey) } ?? "",
            isPresented: confirmationBinding,
            presenting: viewModel.pendingConfirmation
        ) { confirmation in
            Button(tr(confirmation.actionKey), role: .destructive) {
                Task { await viewModel.confirm(confirmation) }
            }
            Button(tr(.commonCancel), role: .cancel) {
                viewModel.cancelConfirmation()
            }
        } message: { confirmation in
            if let key = confirmation.messageKey {
                Text(tr(key))
            }
        }
        .onChange(of: viewModel.deletionIssueMessageKey) { key in
            // role="alert": ошибка удаления зачитывается VoiceOver.
            if let key {
                UIAccessibility.post(notification: .announcement, argument: tr(key))
            }
        }
        .accessibilityIdentifier("settings.screen")
    }

    private func tr(_ key: L10nKey) -> String {
        localization.tr(key)
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingConfirmation != nil },
            set: { if !$0 { viewModel.cancelConfirmation() } }
        )
    }

    private func toggleBinding(_ toggle: SettingsToggle) -> Binding<Bool> {
        Binding(
            get: { viewModel.toggleValue(toggle) },
            set: { value in Task { await viewModel.set(toggle, value) } }
        )
    }

    @ViewBuilder
    private func content(_ settings: AppSettings) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // .topbar h1
            Text(tr(.tabSettings))
                .themeFont(.headingMD)
                .foregroundColor(Theme.Color.text)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Theme.Space.topbarTop)
                .padding(.bottom, Theme.Space.topbarBottom)
                .padding(.horizontal, Theme.Space.s4)
                .frame(maxWidth: .infinity, minHeight: Theme.Space.topbarMinHeight, alignment: .leading)

            VStack(alignment: .leading, spacing: 0) {
                SettingsAccountSection(
                    state: viewModel.accountState,
                    deletionIssueKey: viewModel.deletionIssueMessageKey,
                    tr: { tr($0) },
                    onApple: { viewModel.signInWithApple() },
                    onGoogle: { viewModel.signInWithGoogle() },
                    onSignOut: { viewModel.request(.signOut) },
                    onDelete: { viewModel.request(.deleteAccount) },
                    onRetryDeletion: { Task { await viewModel.deleteAccount() } },
                    onPrivacy: { viewModel.openPrivacy() }
                )

                languageSection(selected: settings.lang)

                AppSectionHeader(title: tr(.setFeedback))
                AppList {
                    toggleRow(.haptics, .setHaptics, first: true)
                    toggleRow(.sound, .setSound)
                }

                AppSectionHeader(title: tr(.setMotion))
                AppList {
                    toggleRow(.animations, .setAnimations, first: true)
                    toggleRow(.banners, .setBanners)
                    SettingsSwitchRow {
                        Text(tr(.setSystemRM))
                            .themeFont(.body)
                            .foregroundColor(Theme.Color.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(tr(viewModel.systemReduceMotion ? .commonOn : .commonOff))
                            .themeFont(.body)
                            .foregroundColor(Theme.Color.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.systemRM")
                }

                AppSectionHeader(title: tr(.setDisplay))
                AppList {
                    toggleRow(.translit, .setTranslit, first: true)
                    toggleRow(.translation, .setTranslation)
                    toggleRow(.keepAwake, .setKeepAwake)
                }

                AppSectionHeader(title: tr(.setStats))
                AppList {
                    toggleRow(.goalOn, .setGoal, first: true)
                    if settings.goalOn {
                        goalRow(goal: settings.goal)
                    }
                    AppListRow(title: tr(.historyClear), kind: .destructive) {
                        viewModel.request(.clearHistory)
                    }
                    .accessibilityIdentifier("settings.clearHistory")
                }
                AppFootnote(text: tr(.setStatsFoot))

                // .list style="margin-top:22px"
                AppList {
                    AppListRow(title: tr(.setDefaults), showsTopDivider: false) {
                        viewModel.request(.resetDefaults)
                    }
                    .accessibilityIdentifier("settings.defaults")
                    AppListRow(title: tr(.setReset), kind: .destructive) {
                        viewModel.request(.resetProgress)
                    }
                    .accessibilityIdentifier("settings.reset")
                }
                .padding(.top, Theme.Space.groupHeaderTop)

                AppFootnote(text: tr(.setSaveDevice))
                    .accessibilityIdentifier("settings.saveWhere")
            }
            .padding(.horizontal, Theme.Space.screenX)
            .padding(.bottom, Theme.Space.screenBottom)
        }
    }

    private func toggleRow(_ toggle: SettingsToggle, _ title: L10nKey, first: Bool = false) -> some View {
        AppToggleRow(
            title: tr(title),
            isOn: toggleBinding(toggle),
            showsTopDivider: !first,
            onValue: tr(.commonOn),
            offValue: tr(.commonOff)
        )
        .accessibilityIdentifier("settings.toggle.\(toggle.rawValue)")
    }

    private func languageSection(selected: AppLanguage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AppSectionHeader(title: tr(.setLanguage))
            AppChipFlowLayout(spacing: Theme.Space.s2) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    AppChip(
                        title: LocalizationService.nativeName(of: language),
                        isSelected: language == selected
                    ) {
                        Task { await viewModel.selectLanguage(language) }
                    }
                    .accessibilityIdentifier("settings.lang.\(language.rawValue)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            AppFootnote(text: tr(.setLangNote))
        }
    }

    /// `.switch` со значением цели и `.stepper` (−/+ по 10).
    private func goalRow(goal: Int) -> some View {
        let title = localization.tr(.setGoalValue, localization.format(goal))
        return SettingsSwitchRow {
            Text(title)
                .themeFont(.body)
                .foregroundColor(Theme.Color.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("settings.goal.value")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: Task { await viewModel.stepGoal(by: GoalRules.step) }
                    case .decrement: Task { await viewModel.stepGoal(by: -GoalRules.step) }
                    @unknown default: break
                    }
                }
            HStack(spacing: Theme.Space.s2) {
                StepperButton(symbol: "−", label: "−10") {
                    Task { await viewModel.stepGoal(by: -GoalRules.step) }
                }
                .accessibilityIdentifier("settings.goal.minus")
                StepperButton(symbol: "+", label: "+10") {
                    Task { await viewModel.stepGoal(by: GoalRules.step) }
                }
                .accessibilityIdentifier("settings.goal.plus")
            }
        }
    }
}

/// `.switch`: строка 52 pt, padding 12/14, разделитель сверху.
private struct SettingsSwitchRow<Content: View>: View {
    var showsTopDivider = true
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.s3) {
            content
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
    }
}

/// `.stepper button`: 40×36, radius 10, divider, surface2, bold.
private struct StepperButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .themeFont(.bodyStrong)
                .foregroundColor(Theme.Color.text)
                .frame(width: StepperMetrics.width, height: StepperMetrics.height)
                .background(Theme.Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chipButton, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.chipButton, style: .continuous)
                        .strokeBorder(Theme.Color.divider, lineWidth: Theme.Size.hairline)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private enum StepperMetrics {
    static let width: CGFloat = 40
    static let height: CGFloat = 36
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "SettingsView") {
            SettingsView(viewModel: makeViewModel(auth: .guest))
        }
        ThemePreview.pair(name: "SettingsView · signed in") {
            SettingsView(viewModel: makeViewModel(auth: .signedIn(user: AuthUser(
                uid: "preview",
                displayName: "Komron",
                email: "preview@example.com",
                provider: "apple"
            ))))
        }
    }

    @MainActor
    private static func makeViewModel(auth: AuthState) -> SettingsViewModel {
        let viewModel = SettingsViewModel(
            repository: PreviewSettingsRepository(),
            sink: PreviewSettingsSink(),
            authService: UITestAuthService(state: auth),
            localization: LocalizationService(language: .ru, defaults: nil),
            reduceMotion: SystemReduceMotionProvider(),
            urlOpener: SafariURLOpener(presenter: KeyWindowPresenterProvider()),
            presenter: KeyWindowPresenterProvider()
        )
        Task { await viewModel.start() }
        return viewModel
    }
}

private struct PreviewSettingsRepository: SettingsRepository {
    func load() async -> AppSettings? { AppSettings(lang: .ru) }
    func update(_ mutate: @Sendable (inout AppSettings) -> Void) async throws -> AppSettings {
        var settings = AppSettings(lang: .ru)
        mutate(&settings)
        return settings
    }
    func changes() async -> AsyncStream<AppSettings> { AsyncStream { _ in } }
}

private struct PreviewSettingsSink: SettingsCommandSink {
    func set(_ field: SettingsField) async -> Bool { true }
    func setLanguage(_ language: AppLanguage) async -> Bool { true }
    func resetDefaults() async -> Bool { true }
    func clearHistory() async -> Bool { true }
    func resetProgress() async -> Bool { true }
}
#endif
