// SettingsViewModel.swift
// ZKR-50: состояние нативного экрана «Настройки».
// Чтение — SettingsRepository (zikr-state.json, зеркало веба): load() и changes().
// Запись — только команды в веб (SettingsCommandSink → window.zikrNative.*): веб остаётся
// единственным писателем. UI обновляется оптимистично, затем значение веба из changes() побеждает.
// Аккаунт — AuthService (AuthCoordinator), удаление — сценарий ZKR-56 (AccountDeletionFlow).

import Combine
import Foundation
import ZikrCore
import ZikrDomain

/// Что показывает блок «Аккаунт» (порядок и тексты — как renderSettings() в index.html).
enum SettingsAccountState: Equatable {
    case guest
    case signingIn
    case signedIn(name: String?, providerKey: L10nKey, email: String?)
    /// message — текст ошибки, note — сноска под ним (auth.local) или nil.
    case error(message: L10nKey, note: L10nKey?)
    case deleting

    init(_ state: AuthState) {
        switch state {
        case .guest:
            self = .guest
        case .signingIn:
            self = .signingIn
        case .signedIn(let user):
            let name = user.displayName.flatMap { $0.isEmpty ? nil : $0 }
            let email = user.email.flatMap { $0.isEmpty ? nil : $0 }
            self = .signedIn(
                name: name,
                providerKey: user.provider == "google" ? .authProviderGoogle : .authProviderApple,
                email: email
            )
        case .error(let message, _):
            switch message {
            case "offline": self = .error(message: .authOffline, note: .authLocal)
            case "reauth": self = .error(message: .authReauth, note: nil)
            case "accountExists": self = .error(message: .authAccountExists, note: nil)
            default: self = .error(message: .authError, note: .authLocal)
            }
        case .deleting:
            self = .deleting
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    /// Ссылка «Конфиденциальность» — тот же URL, что data-ext-link в renderSettings().
    static let privacyURL = URL(string: "https://khisomovkomron.github.io/zikr-adventure/privacy.html")!

    /// nil — zikr-state.json ещё нет (зеркало не получило снимок): показывается веб-экран.
    @Published private(set) var settings: AppSettings?
    @Published private(set) var auth: AuthState
    /// ZKR-56: ошибка последнего удаления аккаунта (показывается с кнопкой «Повторить»).
    @Published private(set) var deletionIssue: AccountDeletionOutcome?
    @Published var pendingConfirmation: SettingsConfirmation?
    @Published private(set) var systemReduceMotion: Bool

    let localization: LocalizationService

    private let repository: any SettingsRepository
    private let sink: any SettingsCommandSink
    private let authService: any AuthService
    private let reduceMotion: any ReduceMotionProviding
    private let urlOpener: any URLOpening
    private let presenter: any PresenterProviding
    private var subscriptions: Set<AnyCancellable> = []
    private var isStarted = false

    init(
        repository: any SettingsRepository,
        sink: any SettingsCommandSink,
        authService: any AuthService,
        localization: LocalizationService,
        reduceMotion: any ReduceMotionProviding,
        urlOpener: any URLOpening,
        presenter: any PresenterProviding
    ) {
        self.repository = repository
        self.sink = sink
        self.authService = authService
        self.localization = localization
        self.reduceMotion = reduceMotion
        self.urlOpener = urlOpener
        self.presenter = presenter
        self.auth = authService.state
        self.systemReduceMotion = reduceMotion.isReduceMotionEnabled
    }

    var isAvailable: Bool { settings != nil }
    var accountState: SettingsAccountState { SettingsAccountState(auth) }

    /// Подписки и чтение настроек. Работает, пока жив вызывающий Task (TabsView.task).
    func start() async {
        guard !isStarted else { return }
        isStarted = true
        defer { isStarted = false }

        authService.activate()
        authService.statePublisher
            .removeDuplicates()
            .sink { [weak self] state in self?.handleAuthState(state) }
            .store(in: &subscriptions)
        reduceMotion.changes
            .removeDuplicates()
            .sink { [weak self] enabled in self?.systemReduceMotion = enabled }
            .store(in: &subscriptions)
        defer { subscriptions.removeAll() }

        // Сначала подписка, потом load(): запись между ними не теряется.
        let stream = await repository.changes()
        if let loaded = await repository.load() {
            apply(loaded)
        }
        for await next in stream {
            apply(next)
        }
    }

    // MARK: - Настройки

    func toggleValue(_ toggle: SettingsToggle) -> Bool {
        settings?[toggle] ?? false
    }

    func set(_ toggle: SettingsToggle, _ value: Bool) async {
        await send(.toggle(toggle, value))
    }

    /// Кнопки −/+ (шаг 10, 10…10000).
    func stepGoal(by delta: Int) async {
        guard let goal = settings?.goal else { return }
        let next = GoalRules.stepped(goal, by: delta)
        guard next != goal else { return }
        await send(.goal(next))
    }

    func selectLanguage(_ language: AppLanguage) async {
        guard var current = settings, current.lang != language else { return }
        current.lang = language
        settings = current
        localization.setLanguage(language)
        if !(await sink.setLanguage(language)) {
            await reload()
        }
    }

    // MARK: - Подтверждения

    func request(_ confirmation: SettingsConfirmation) {
        pendingConfirmation = confirmation
    }

    func cancelConfirmation() {
        pendingConfirmation = nil
    }

    /// Действие после «ОК» в подтверждении.
    func confirm(_ confirmation: SettingsConfirmation) async {
        pendingConfirmation = nil
        switch confirmation {
        case .signOut:
            do {
                try await authService.signOut()
            } catch {
                let nsError = error as NSError
                Log.auth.error("Sign out failed (domain: \(nsError.domain, privacy: .public), code: \(nsError.code, privacy: .public))")
            }
        case .deleteAccount:
            await deleteAccount()
        case .clearHistory:
            await sink.clearHistory()
        case .resetDefaults:
            // Как restoreDefaultSettings(): { ...DEFAULT_SETTINGS, lang: L() }.
            if let lang = settings?.lang {
                settings = AppSettings(lang: lang)
            }
            if !(await sink.resetDefaults()) {
                await reload()
            }
        case .resetProgress:
            // Настройки при сбросе прогресса не меняются.
            await sink.resetProgress()
        }
    }

    // MARK: - Аккаунт

    func signInWithApple() {
        deletionIssue = nil
        authService.signInWithApple()
    }

    func signInWithGoogle() {
        deletionIssue = nil
        guard let top = presenter.topViewController() else { return }
        authService.signInWithGoogle(presenter: top)
    }

    /// ZKR-56: удаление (после подтверждения) и «Повторить».
    func deleteAccount() async {
        deletionIssue = nil
        guard let top = presenter.topViewController() else { return }
        let outcome = await authService.deleteAccount(presenter: top)
        deletionIssue = outcome.isIssue ? outcome : nil
    }

    var deletionIssueMessageKey: L10nKey? {
        switch deletionIssue {
        case .revokeFailed: return .authRevokeFailed
        case .offline: return .authOffline
        case .failed: return .authError
        default: return nil
        }
    }

    func openPrivacy() {
        urlOpener.open(Self.privacyURL)
    }

    // MARK: - Внутреннее

    private func send(_ field: SettingsField) async {
        guard var current = settings else { return }
        field.apply(to: &current)
        settings = current
        if !(await sink.set(field)) {
            await reload()
        }
    }

    /// Команда не выполнена — вернуть то, что реально сохранено.
    private func reload() async {
        if let loaded = await repository.load() {
            apply(loaded)
        }
    }

    /// Значение веба (zikr-state.json) побеждает оптимистичное.
    private func apply(_ loaded: AppSettings) {
        if settings != loaded {
            settings = loaded
        }
        localization.setLanguage(loaded.lang)
    }

    private func handleAuthState(_ state: AuthState) {
        auth = state
        switch state {
        case .guest, .signingIn:
            deletionIssue = nil
        default:
            break
        }
    }
}
