// TestDoubles.swift
// ZKR-50: подставные зависимости для SettingsViewModel и AccountDeletionFlow.

import Combine
import UIKit
import XCTest
import ZikrDomain
@testable import ZikrAdventure

actor FakeSettingsRepository: SettingsRepository {
    private(set) var stored: AppSettings?
    private var continuations: [AsyncStream<AppSettings>.Continuation] = []

    init(_ stored: AppSettings?) {
        self.stored = stored
    }

    func load() -> AppSettings? { stored }

    func update(_ mutate: @Sendable (inout AppSettings) -> Void) throws -> AppSettings {
        var value = stored ?? AppSettings()
        mutate(&value)
        stored = value
        return value
    }

    func changes() -> AsyncStream<AppSettings> {
        let (stream, continuation) = AsyncStream.makeStream(of: AppSettings.self)
        continuations.append(continuation)
        return stream
    }

    /// Как запись веба через зеркало: файл меняется и подписчики получают значение.
    func emit(_ value: AppSettings) {
        stored = value
        continuations.forEach { $0.yield(value) }
    }

    var subscriberCount: Int { continuations.count }
}

@MainActor
final class FakeSettingsSink: SettingsCommandSink {
    enum Call: Equatable {
        case set(SettingsField)
        case language(AppLanguage)
        case resetDefaults, clearHistory, resetProgress
    }

    var calls: [Call] = []
    var result = true

    func set(_ field: SettingsField) async -> Bool { calls.append(.set(field)); return result }
    func setLanguage(_ language: AppLanguage) async -> Bool { calls.append(.language(language)); return result }
    func resetDefaults() async -> Bool { calls.append(.resetDefaults); return result }
    func clearHistory() async -> Bool { calls.append(.clearHistory); return result }
    func resetProgress() async -> Bool { calls.append(.resetProgress); return result }
}

@MainActor
final class FakeAuthService: AuthService {
    @Published var state: AuthState
    var statePublisher: AnyPublisher<AuthState, Never> { $state.eraseToAnyPublisher() }
    var activateCount = 0
    var signOutCount = 0
    var appleSignInCount = 0
    var googleSignInCount = 0
    var deleteOutcome: AccountDeletionOutcome = .deleted
    var deleteCount = 0

    init(state: AuthState) {
        self.state = state
    }

    func activate() { activateCount += 1 }
    func signInWithApple() { appleSignInCount += 1 }
    func signInWithGoogle(presenter: UIViewController) { googleSignInCount += 1 }
    func signOut() async throws { signOutCount += 1; state = .guest }

    func deleteAccount(presenter: UIViewController) async -> AccountDeletionOutcome {
        deleteCount += 1
        if deleteOutcome == .deleted { state = .guest }
        return deleteOutcome
    }
}

@MainActor
final class FakeReduceMotion: ReduceMotionProviding {
    let subject = PassthroughSubject<Bool, Never>()
    var isReduceMotionEnabled = false
    var changes: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }
}

@MainActor
final class FakeURLOpener: URLOpening {
    var opened: [URL] = []
    func open(_ url: URL) { opened.append(url) }
}

@MainActor
final class FakePresenter: PresenterProviding {
    let controller = UIViewController()
    func topViewController() -> UIViewController? { controller }
}

let signedInAppleUser = AuthUser(uid: "u1", displayName: "Test", email: "t@example.com", provider: "apple")

/// Ждёт условие, отдавая управление главному потоку (start() и Combine работают на MainActor).
@MainActor
func waitUntil(
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () async -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Condition not met in \(timeout)s", file: file, line: line)
}
