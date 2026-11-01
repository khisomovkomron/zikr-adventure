// SettingsViewModelTests.swift
// ZKR-50: чтение из репозитория, команды в веб, подтверждения, аккаунт и ошибки удаления (ZKR-56).

import XCTest
import ZikrDomain
@testable import ZikrAdventure

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var repository: FakeSettingsRepository!
    private var sink: FakeSettingsSink!
    private var auth: FakeAuthService!
    private var reduceMotion: FakeReduceMotion!
    private var opener: FakeURLOpener!
    private var localization: LocalizationService!
    private var viewModel: SettingsViewModel!
    private var startTask: Task<Void, Never>?

    override func setUp() async throws {
        repository = FakeSettingsRepository(AppSettings(goalOn: true, goal: 100, lang: .ru))
        sink = FakeSettingsSink()
        auth = FakeAuthService(state: .guest)
        reduceMotion = FakeReduceMotion()
        opener = FakeURLOpener()
        localization = LocalizationService(language: .en, defaults: nil)
        viewModel = SettingsViewModel(
            repository: repository,
            sink: sink,
            authService: auth,
            localization: localization,
            reduceMotion: reduceMotion,
            urlOpener: opener,
            presenter: FakePresenter()
        )
    }

    override func tearDown() async throws {
        startTask?.cancel()
        startTask = nil
    }

    private func start() async {
        let viewModel = self.viewModel!
        startTask = Task { await viewModel.start() }
        await waitUntil { viewModel.isAvailable }
    }

    func testNoStateFileKeepsWebScreen() async {
        repository = FakeSettingsRepository(nil)
        viewModel = SettingsViewModel(
            repository: repository, sink: sink, authService: auth, localization: localization,
            reduceMotion: reduceMotion, urlOpener: opener, presenter: FakePresenter()
        )
        let viewModel = self.viewModel!
        startTask = Task { await viewModel.start() }
        await waitUntil { await self.repository.subscriberCount == 1 }
        XCTAssertFalse(viewModel.isAvailable)
    }

    func testStartLoadsSettingsActivatesAuthAndAppliesLanguage() async {
        await start()
        XCTAssertEqual(viewModel.settings?.goal, 100)
        XCTAssertEqual(auth.activateCount, 1)
        XCTAssertEqual(localization.language, .ru)
    }

    func testToggleIsOptimisticAndSendsCommand() async {
        await start()
        await viewModel.set(.animations, false)
        XCTAssertEqual(viewModel.toggleValue(.animations), false)
        XCTAssertEqual(sink.calls, [.set(.toggle(.animations, false))])
    }

    func testFailedCommandRestoresStoredValue() async {
        await start()
        sink.result = false
        await viewModel.set(.haptics, false)
        XCTAssertEqual(viewModel.toggleValue(.haptics), true)
    }

    func testWebValueWins() async {
        await start()
        await viewModel.set(.sound, true)
        await repository.emit(AppSettings(sound: false, goalOn: true, goal: 300, lang: .uz))
        await waitUntil { self.viewModel.settings?.goal == 300 }
        XCTAssertEqual(viewModel.toggleValue(.sound), false)
        XCTAssertEqual(localization.language, .uz)
    }

    func testGoalStepsByTenWithinBounds() async {
        await start()
        await viewModel.stepGoal(by: GoalRules.step)
        await viewModel.stepGoal(by: GoalRules.step)
        XCTAssertEqual(viewModel.settings?.goal, 120)
        XCTAssertEqual(sink.calls, [.set(.goal(110)), .set(.goal(120))])

        await repository.emit(AppSettings(goalOn: true, goal: 10, lang: .ru))
        await waitUntil { self.viewModel.settings?.goal == 10 }
        sink.calls = []
        await viewModel.stepGoal(by: -GoalRules.step)
        XCTAssertEqual(sink.calls, [], "below minimum: no command")
    }

    func testGoalTitleUsesLanguageLocale() async {
        await start()
        await repository.emit(AppSettings(goalOn: true, goal: 10_000, lang: .ru))
        await waitUntil { self.viewModel.settings?.goal == 10_000 }
        let title = localization.tr(.setGoalValue, localization.format(10_000))
        XCTAssertEqual(title, "Цель: 10\u{00A0}000")
    }

    func testSelectLanguageUpdatesUIImmediately() async {
        await start()
        await viewModel.selectLanguage(.uz)
        XCTAssertEqual(localization.language, .uz)
        XCTAssertEqual(viewModel.settings?.lang, .uz)
        XCTAssertEqual(sink.calls, [.language(.uz)])
        XCTAssertEqual(localization.tr(.tabSettings), "Sozlamalar")
    }

    func testResetDefaultsKeepsLanguage() async {
        await start()
        await viewModel.set(.keepAwake, true)
        viewModel.request(.resetDefaults)
        XCTAssertEqual(viewModel.pendingConfirmation, .resetDefaults)
        await viewModel.confirm(.resetDefaults)
        XCTAssertNil(viewModel.pendingConfirmation)
        XCTAssertEqual(viewModel.settings, AppSettings(lang: .ru))
        XCTAssertEqual(sink.calls.last, .resetDefaults)
    }

    func testDestructiveConfirmationsSendCommands() async {
        await start()
        await viewModel.confirm(.clearHistory)
        await viewModel.confirm(.resetProgress)
        XCTAssertEqual(sink.calls, [.clearHistory, .resetProgress])
        XCTAssertEqual(viewModel.settings?.goal, 100, "settings untouched by progress reset")
    }

    func testCancelConfirmationDoesNothing() async {
        await start()
        viewModel.request(.resetProgress)
        viewModel.cancelConfirmation()
        XCTAssertNil(viewModel.pendingConfirmation)
        XCTAssertEqual(sink.calls, [])
    }

    func testSignOut() async {
        auth.state = .signedIn(user: signedInAppleUser)
        await start()
        await viewModel.confirm(.signOut)
        XCTAssertEqual(auth.signOutCount, 1)
        await waitUntil { self.viewModel.accountState == .guest }
    }

    func testRevokeFailureShowsIssueAndRetry() async {
        auth.state = .signedIn(user: signedInAppleUser)
        auth.deleteOutcome = .revokeFailed
        await start()
        await viewModel.confirm(.deleteAccount)
        XCTAssertEqual(viewModel.deletionIssue, .revokeFailed)
        XCTAssertEqual(viewModel.deletionIssueMessageKey, .authRevokeFailed)

        auth.deleteOutcome = .deleted
        await viewModel.deleteAccount()
        XCTAssertEqual(auth.deleteCount, 2)
        XCTAssertNil(viewModel.deletionIssue)
        await waitUntil { self.viewModel.accountState == .guest }
    }

    func testCancelledDeletionIsSilent() async {
        auth.state = .signedIn(user: signedInAppleUser)
        auth.deleteOutcome = .cancelled
        await start()
        await viewModel.deleteAccount()
        XCTAssertNil(viewModel.deletionIssue)
    }

    func testOfflineDeletionMessage() async {
        auth.state = .signedIn(user: signedInAppleUser)
        auth.deleteOutcome = .offline
        await start()
        await viewModel.deleteAccount()
        XCTAssertEqual(viewModel.deletionIssueMessageKey, .authOffline)
    }

    func testIssueClearedWhenSignedOut() async {
        auth.state = .signedIn(user: signedInAppleUser)
        auth.deleteOutcome = .failed
        await start()
        await viewModel.deleteAccount()
        XCTAssertEqual(viewModel.deletionIssueMessageKey, .authError)
        auth.state = .guest
        await waitUntil { self.viewModel.deletionIssue == nil }
    }

    func testSignInButtons() async {
        await start()
        viewModel.signInWithApple()
        viewModel.signInWithGoogle()
        XCTAssertEqual(auth.appleSignInCount, 1)
        XCTAssertEqual(auth.googleSignInCount, 1)
    }

    func testReduceMotionFollowsSystem() async {
        await start()
        XCTAssertFalse(viewModel.systemReduceMotion)
        reduceMotion.subject.send(true)
        await waitUntil { self.viewModel.systemReduceMotion }
    }

    func testPrivacyLink() async {
        viewModel.openPrivacy()
        XCTAssertEqual(opener.opened, [URL(string: "https://khisomovkomron.github.io/zikr-adventure/privacy.html")!])
    }

    func testAccountStateMapping() {
        XCTAssertEqual(SettingsAccountState(.error(message: "offline", retryable: true)), .error(message: .authOffline, note: .authLocal))
        XCTAssertEqual(SettingsAccountState(.error(message: "reauth", retryable: false)), .error(message: .authReauth, note: nil))
        XCTAssertEqual(SettingsAccountState(.error(message: "accountExists", retryable: true)), .error(message: .authAccountExists, note: nil))
        XCTAssertEqual(SettingsAccountState(.error(message: "boom", retryable: true)), .error(message: .authError, note: .authLocal))
        XCTAssertEqual(
            SettingsAccountState(.signedIn(user: AuthUser(uid: "u", displayName: "", email: nil, provider: "google"))),
            .signedIn(name: nil, providerKey: .authProviderGoogle, email: nil)
        )
    }

    func testConfirmationTexts() {
        XCTAssertNil(SettingsConfirmation.resetDefaults.messageKey)
        XCTAssertEqual(SettingsConfirmation.resetProgress.actionKey, .setResetA)
        XCTAssertEqual(SettingsConfirmation.deleteAccount.titleKey, .authDeleteTitle)
    }
}
