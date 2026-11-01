// AuthService.swift
// ZKR-50: протокол авторизации для нативного экрана «Настройки» и моста в веб.
// Живая реализация — AuthCoordinator (один экземпляр в AppContainer).

import Combine
import UIKit

@MainActor
protocol AuthService: AnyObject {
    var state: AuthState { get }
    /// Текущее значение и все последующие (как @Published).
    var statePublisher: AnyPublisher<AuthState, Never> { get }

    /// Подключает слушатель сессии Firebase. Идемпотентно; вызывать после FirebaseApp.configure().
    func activate()
    func signInWithApple()
    func signInWithGoogle(presenter: UIViewController)
    func signOut() async throws
    func deleteAccount(presenter: UIViewController) async -> AccountDeletionOutcome
}

/// Верхний view controller для системных окон входа (Google) из SwiftUI.
@MainActor
protocol PresenterProviding: AnyObject {
    func topViewController() -> UIViewController?
}

@MainActor
final class KeyWindowPresenterProvider: PresenterProviding {
    func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

#if DEBUG
/// UI-тесты: вход без Firebase (`ZIKR_UITEST_AUTH=signedIn`). Удаление показывает подсказку reauth
/// и «отменяется» — системное окно не открывается.
@MainActor
final class UITestAuthService: AuthService {
    @Published private(set) var state: AuthState
    var statePublisher: AnyPublisher<AuthState, Never> { $state.eraseToAnyPublisher() }

    init(state: AuthState) {
        self.state = state
    }

    static func fromEnvironment(_ environment: [String: String]) -> UITestAuthService? {
        switch environment["ZIKR_UITEST_AUTH"] {
        case "signedIn":
            return UITestAuthService(state: .signedIn(user: AuthUser(
                uid: "ui-test",
                displayName: "UI Test",
                email: "ui-test@example.com",
                provider: "apple"
            )))
        case "guest":
            return UITestAuthService(state: .guest)
        default:
            return nil
        }
    }

    func activate() {}
    func signInWithApple() {}
    func signInWithGoogle(presenter: UIViewController) {}
    func signOut() async throws { state = .guest }

    func deleteAccount(presenter: UIViewController) async -> AccountDeletionOutcome {
        guard case .signedIn(let user) = state else { return .notSignedIn }
        state = .error(message: "reauth", retryable: false)
        try? await Task.sleep(nanoseconds: 8_000_000_000)
        state = .signedIn(user: user)
        return .cancelled
    }
}
#endif
