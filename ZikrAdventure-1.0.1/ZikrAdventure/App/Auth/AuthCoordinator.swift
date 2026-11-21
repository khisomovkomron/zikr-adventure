// AuthCoordinator.swift
// Координатор авторизации для Google и Apple Sign-In через Firebase Authentication.
// Состояния: guest → signingIn → signedIn/error. Поддерживает выход и удаление аккаунта.
// Восстановление сессии через Firebase listener; только одна операция входа/удаления одновременно.
// ZKR-50: один экземпляр в AppContainer (раньше — в WebAppViewController); состояние — @Published,
// его слушают и нативный экран «Настройки», и мост в веб (zikr:auth). Слушатель Firebase
// подключается в activate(), а не в init — контейнер создаётся до FirebaseApp.configure().
// ZKR-56: удаление аккаунта — AccountDeletionFlow (всегда повторный вход; ошибка отзыва Apple → не удалять).

import Combine
import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import os
import ZikrCore

/// Логгер авторизации: пишет только domain/code ошибок (без токенов и nonce). ZKR-23.
let authLogger = Log.auth

/// Состояния авторизации
enum AuthState: Equatable {
    case guest
    case signingIn(provider: String)
    case signedIn(user: AuthUser)
    case error(message: String, retryable: Bool)
    case deleting
}

/// Данные пользователя для UI
struct AuthUser: Equatable {
    let uid: String
    let displayName: String?
    let email: String?
    let provider: String
}

/// Координатор авторизации
@MainActor
final class AuthCoordinator: NSObject, ObservableObject, AuthService {
    @Published private(set) var state: AuthState = .guest
    var statePublisher: AnyPublisher<AuthState, Never> { $state.eraseToAnyPublisher() }
    
    private var currentNonce: String?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var requestGeneration: UInt64 = 0 // Issue 13: Guard against stale callbacks
    private var savedAppleAuthCode: String? // Issue 3: Store Apple auth code for token revocation
    
    override init() {
        super.init()
    }

    /// Подключает слушатель Firebase (восстановление сессии). Повторный вызов ничего не делает.
    func activate() {
        guard authStateListener == nil else { return }
        setupAuthListener()
    }
    
    deinit {
        if let handle = authStateListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Session Restoration
    
    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            Task { @MainActor in
                if let user = user, case .signingIn = self.state {
                    // Вход завершён успешно
                    self.updateState(.signedIn(user: self.makeAuthUser(from: user)))
                } else if user == nil, case .signedIn = self.state {
                    // Сессия завершена (выход или истечение)
                    self.updateState(.guest)
                } else if let user = user, case .guest = self.state {
                    // Восстановление существующей сессии при запуске
                    self.updateState(.signedIn(user: self.makeAuthUser(from: user)))
                }
            }
        }
    }
    
    private func makeAuthUser(from firebaseUser: User) -> AuthUser {
        let providerID = firebaseUser.providerData.first?.providerID ?? "unknown"
        let provider: String
        switch providerID {
        case "google.com":
            provider = "google"
        case "apple.com":
            provider = "apple"
        default:
            provider = providerID
        }
        
        return AuthUser(
            uid: firebaseUser.uid,
            displayName: firebaseUser.displayName,
            email: firebaseUser.email,
            provider: provider
        )
    }
    
    private func updateState(_ newState: AuthState) {
        state = newState
    }
    
    // MARK: - Sign In with Google
    
    func signInWithGoogle(presenter presentingViewController: UIViewController) {
        // Issue 1: Allow retry from error state
        switch state {
        case .guest, .error: break // retry allowed from error state
        default: return
        }
        
        requestGeneration += 1 // Issue 13: New request generation
        let generation = requestGeneration
        
        updateState(.signingIn(provider: "google"))
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            updateState(.error(message: "Firebase configuration missing", retryable: false))
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            guard let self = self else { return }
            Task { @MainActor in
                await self.handleGoogleSignInResult(result: result, error: error, generation: generation)
            }
        }
    }
    
    private func handleGoogleSignInResult(result: GIDSignInResult?, error: Error?, generation: UInt64) async {
        // Issue 13: Check if this callback is still relevant
        guard generation == requestGeneration else { return }
        
        if let error = error as NSError? {
            if error.code == -5 { // User cancelled
                updateState(.guest)
                return
            }
            // Issue 6: Better network error detection for GoogleSignIn
            let isNetworkError = error.domain == NSURLErrorDomain || 
                                 (error.domain == "com.google.GIDSignIn" && error.code == -4) // GIDSignInErrorCodeNetworkError
            updateState(.error(
                message: isNetworkError ? "offline" : "error",
                retryable: true
            ))
            return
        }
        
        guard let user = result?.user,
              let idToken = user.idToken?.tokenString else {
            updateState(.error(message: "error", retryable: true))
            return
        }
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString
        )
        
        do {
            _ = try await Auth.auth().signIn(with: credential)
            // Состояние обновится через authStateListener
        } catch {
            // Issue 13: Check if still relevant
            guard generation == requestGeneration else { return }
            
            let nsError = error as NSError
            // Issue 6: Better network error detection for Firebase Auth
            let isNetworkError = nsError.domain == NSURLErrorDomain || 
                                 nsError.code == AuthErrorCode.networkError.rawValue
            // Issue 7: Handle account-exists-with-different-credential
            if nsError.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue {
                updateState(.error(message: "accountExists", retryable: false))
                return
            }
            updateState(.error(
                message: isNetworkError ? "offline" : "error",
                retryable: true
            ))
        }
    }
    
    // MARK: - Sign In with Apple
    
    func signInWithApple() {
        // Issue 1: Allow retry from error state
        switch state {
        case .guest, .error: break // retry allowed from error state
        default: return
        }
        
        requestGeneration += 1 // Issue 13: New request generation
        
        updateState(.signingIn(provider: "apple"))
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        try Auth.auth().signOut()
        // Состояние обновится через authStateListener
    }
    
    // MARK: - Delete Account
    
    /// ZKR-56: сценарий AccountDeletionFlow. Состояние меняется внутри сценария; итог — для UI.
    func deleteAccount(presenter: UIViewController) async -> AccountDeletionOutcome {
        guard case .signedIn(let user) = state else { return .notSignedIn }
        let flow = AccountDeletionFlow(
            backend: FirebaseAccountDeletionBackend(coordinator: self, presenter: presenter),
            log: { authLogger.error("\($0, privacy: .public)") }
        )
        return await flow.run(user: user) { [weak self] newState in
            self?.updateState(newState)
        }
    }

    /// Повторный вход у провайдера. Apple — возвращает свежий authorization code (одноразовый).
    fileprivate func reauthenticate(provider: String, presentingViewController: UIViewController) async throws -> String? {
        switch provider {
        case "google":
            try await reauthenticateWithGoogle(presentingViewController: presentingViewController)
            return nil
        case "apple":
            savedAppleAuthCode = nil
            try await reauthenticateWithApple()
            let code = savedAppleAuthCode
            savedAppleAuthCode = nil
            return code
        default:
            throw AccountDeletionError.unsupportedProvider
        }
    }
    
    private func reauthenticateWithGoogle(presentingViewController: UIViewController) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "AuthCoordinator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase configuration missing"])
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    continuation.resume(throwing: NSError(domain: "AuthCoordinator", code: -2, userInfo: [NSLocalizedDescriptionKey: "Google sign in failed"]))
                    return
                }
                
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: user.accessToken.tokenString
                )
                
                Task {
                    do {
                        guard let currentUser = Auth.auth().currentUser else {
                            throw AccountDeletionError.noCurrentUser
                        }
                        try await currentUser.reauthenticate(with: credential)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func reauthenticateWithApple() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = []
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.appleReauthContinuation = continuation
            controller.performRequests()
        }
    }
    
    private var appleReauthContinuation: CheckedContinuation<Void, Error>?
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthCoordinator: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                            didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            await handleAppleAuthorization(authorization)
        }
    }
    
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                            didCompleteWithError error: Error) {
        Task { @MainActor in
            handleAppleError(error)
        }
    }
    
    private func handleAppleAuthorization(_ authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            // ZKR-23: логируем, какой именно элемент отсутствует
            let appleCred = authorization.credential as? ASAuthorizationAppleIDCredential
            authLogger.error("Apple sign-in: missing data (credential: \(appleCred != nil, privacy: .public), nonce: \(self.currentNonce != nil, privacy: .public), identityToken: \(appleCred?.identityToken != nil, privacy: .public))")
            
            if appleReauthContinuation != nil {
                appleReauthContinuation?.resume(throwing: NSError(domain: "AuthCoordinator", code: -3, userInfo: [NSLocalizedDescriptionKey: "Apple authorization failed"]))
                appleReauthContinuation = nil
            } else {
                updateState(.error(message: "error", retryable: true))
            }
            return
        }
        
        // Issue 3: Save authorization code for token revocation during account deletion
        if let authCode = appleIDCredential.authorizationCode,
           let authCodeString = String(data: authCode, encoding: .utf8) {
            savedAppleAuthCode = authCodeString
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        do {
            if appleReauthContinuation != nil {
                // Повторная авторизация
                guard let currentUser = Auth.auth().currentUser else {
                    throw AccountDeletionError.noCurrentUser
                }
                try await currentUser.reauthenticate(with: credential)
                appleReauthContinuation?.resume()
                appleReauthContinuation = nil
            } else {
                // Первичный вход
                let generation = requestGeneration // Issue 13: Capture current generation
                _ = try await Auth.auth().signIn(with: credential)
                // Issue 13: Check if still relevant
                guard generation == requestGeneration else { return }
                // Состояние обновится через authStateListener
            }
        } catch {
            // ZKR-23: логируем реальную ошибку Firebase
            let loggedError = error as NSError
            authLogger.error("Apple sign-in: Firebase signIn failed (domain: \(loggedError.domain, privacy: .public), code: \(loggedError.code, privacy: .public))")
            if appleReauthContinuation != nil {
                appleReauthContinuation?.resume(throwing: error)
                appleReauthContinuation = nil
            } else {
                // Issue 13: Check if still relevant
                let generation = requestGeneration
                guard generation == requestGeneration else { return }
                
                let nsError = error as NSError
                // Issue 6: Better network error detection
                let isNetworkError = nsError.domain == NSURLErrorDomain || 
                                     nsError.code == AuthErrorCode.networkError.rawValue
                // Issue 7: Handle account-exists-with-different-credential
                if nsError.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue {
                    updateState(.error(message: "accountExists", retryable: false))
                    return
                }
                updateState(.error(
                    message: isNetworkError ? "offline" : "error",
                    retryable: true
                ))
            }
        }
    }
    
    private func handleAppleError(_ error: Error) {
        let nsError = error as NSError
        // ZKR-23: логируем реальную ошибку ASAuthorization (например, 1000 при отсутствии entitlement)
        authLogger.error("Apple sign-in: ASAuthorization failed (domain: \(nsError.domain, privacy: .public), code: \(nsError.code, privacy: .public))")
        
        if appleReauthContinuation != nil {
            appleReauthContinuation?.resume(throwing: error)
            appleReauthContinuation = nil
            return
        }
        
        if nsError.code == 1001 { // User cancelled
            updateState(.guest)
            return
        }
        
        // Issue 6: Better network error detection
        let isNetworkError = nsError.domain == NSURLErrorDomain
        updateState(.error(
            message: isNetworkError ? "offline" : "error",
            retryable: true
        ))
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthCoordinator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            fatalError("No window available")
        }
        return window
    }
}

// MARK: - ZKR-56: live backend для AccountDeletionFlow

@MainActor
private final class FirebaseAccountDeletionBackend: AccountDeletionBackend {
    private weak var coordinator: AuthCoordinator?
    private let presenter: UIViewController

    init(coordinator: AuthCoordinator, presenter: UIViewController) {
        self.coordinator = coordinator
        self.presenter = presenter
    }

    func reauthenticate(provider: String) async throws -> String? {
        guard let coordinator else { throw AccountDeletionError.noCurrentUser }
        return try await coordinator.reauthenticate(provider: provider, presentingViewController: presenter)
    }

    func revokeAppleToken(authorizationCode: String) async throws {
        try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
    }

    func deleteUser() async throws {
        guard let user = Auth.auth().currentUser else { throw AccountDeletionError.noCurrentUser }
        try await user.delete()
    }
}
