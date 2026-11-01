// AccountDeletionFlow.swift
// ZKR-56 (в составе ZKR-50): единый сценарий удаления аккаунта для Apple и Google.
// Порядок: подсказка reauth → повторный вход (всегда) → для Apple отзыв токена свежим кодом →
// удаление пользователя. Ошибка отзыва или отсутствие кода → аккаунт НЕ удаляется.
// Firebase/GoogleSignIn здесь не импортируются — только в live-реализации backend.

import Foundation

/// Итог удаления. Состояние `AuthState` меняет сам сценарий; итог нужен UI для ошибки и «Повторить».
enum AccountDeletionOutcome: Equatable {
    case deleted
    /// Пользователь закрыл системное окно входа — тихо возвращаемся в signedIn.
    case cancelled
    case offline
    case failed
    /// Apple: отзыв токена не удался или нет кода авторизации — аккаунт не удалён.
    case revokeFailed
    case notSignedIn

    /// Ошибка, которую показываем на экране вместе с кнопкой «Повторить».
    var isIssue: Bool {
        switch self {
        case .offline, .failed, .revokeFailed: return true
        case .deleted, .cancelled, .notSignedIn: return false
        }
    }

    /// Сообщение для веб-экрана (`authState.message`), как в 1.1.1.
    var webMessage: String? {
        switch self {
        case .offline: return "offline"
        case .failed, .revokeFailed: return "error"
        case .deleted, .cancelled, .notSignedIn: return nil
        }
    }
}

enum AccountDeletionError: Error, Equatable {
    case noCurrentUser
    case unsupportedProvider
    case missingAppleAuthorizationCode
}

/// Операции, которые выполняет live-реализация (Firebase + GoogleSignIn + AuthenticationServices).
@MainActor
protocol AccountDeletionBackend: AnyObject {
    /// Повторный вход у провайдера. Для Apple возвращает свежий authorization code.
    func reauthenticate(provider: String) async throws -> String?
    func revokeAppleToken(authorizationCode: String) async throws
    func deleteUser() async throws
}

/// Классификация ошибок провайдеров по domain/code (без зависимостей от SDK).
enum AuthErrorClassifier {
    enum Kind: Equatable {
        case cancelled
        case network
        case other
    }

    static let appleDomain = "com.apple.AuthenticationServices.AuthorizationError"
    static let googleDomain = "com.google.GIDSignIn"
    static let firebaseAuthDomain = "FIRAuthErrorDomain"
    /// ASAuthorizationError.canceled
    static let appleCanceledCode = 1001
    /// GIDSignInErrorCode.canceled
    static let googleCanceledCode = -5
    /// AuthErrorCode.networkError. Сетевые ошибки Google Sign-In приходят как NSURLErrorDomain.
    static let firebaseNetworkCode = 17020

    static func classify(_ error: Error) -> Kind {
        let nsError = error as NSError
        if nsError.domain == appleDomain, nsError.code == appleCanceledCode { return .cancelled }
        if nsError.domain == googleDomain, nsError.code == googleCanceledCode { return .cancelled }
        if nsError.domain == NSURLErrorDomain { return .network }
        if nsError.domain == firebaseAuthDomain, nsError.code == firebaseNetworkCode { return .network }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSURLErrorDomain {
            return .network
        }
        return .other
    }
}

@MainActor
struct AccountDeletionFlow {
    let backend: any AccountDeletionBackend
    var log: (String) -> Void = { _ in }

    func run(user: AuthUser, setState: (AuthState) -> Void) async -> AccountDeletionOutcome {
        // Подсказка до появления системного окна (веб показывает auth.reauth).
        setState(.error(message: "reauth", retryable: false))

        let code: String?
        do {
            code = try await backend.reauthenticate(provider: user.provider)
        } catch {
            let outcome = outcome(for: error, step: "reauth")
            setState(.signedIn(user: user))
            return outcome
        }

        setState(.deleting)

        if user.provider == "apple" {
            guard let code, !code.isEmpty else {
                log("Apple account deletion stopped: no authorization code")
                setState(.signedIn(user: user))
                return .revokeFailed
            }
            do {
                try await backend.revokeAppleToken(authorizationCode: code)
            } catch {
                let kind = AuthErrorClassifier.classify(error)
                logError(error, step: "revoke")
                setState(.signedIn(user: user))
                return kind == .network ? .offline : .revokeFailed
            }
        }

        do {
            try await backend.deleteUser()
        } catch {
            let outcome = outcome(for: error, step: "delete")
            setState(.signedIn(user: user))
            return outcome
        }
        setState(.guest)
        return .deleted
    }

    private func outcome(for error: Error, step: String) -> AccountDeletionOutcome {
        switch AuthErrorClassifier.classify(error) {
        case .cancelled:
            return .cancelled
        case .network:
            logError(error, step: step)
            return .offline
        case .other:
            logError(error, step: step)
            return .failed
        }
    }

    private func logError(_ error: Error, step: String) {
        let nsError = error as NSError
        log("Account deletion \(step) failed (domain: \(nsError.domain), code: \(nsError.code))")
    }
}
