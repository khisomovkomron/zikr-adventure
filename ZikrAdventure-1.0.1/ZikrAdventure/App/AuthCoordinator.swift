// AuthCoordinator.swift
// Координатор авторизации для Google и Apple Sign-In через Firebase Authentication.
// Состояния: guest → signingIn → signedIn/error. Поддерживает выход и удаление аккаунта.
// Восстановление сессии через Firebase listener; только одна операция входа/удаления одновременно.

import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

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
final class AuthCoordinator: NSObject {
    private(set) var state: AuthState = .guest
    var onStateChange: ((AuthState) -> Void)?
    
    private var currentNonce: String?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    override init() {
        super.init()
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
        onStateChange?(newState)
    }
    
    // MARK: - Sign In with Google
    
    func signInWithGoogle(presentingViewController: UIViewController) {
        guard case .guest = state else { return }
        
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
                await self.handleGoogleSignInResult(result: result, error: error)
            }
        }
    }
    
    private func handleGoogleSignInResult(result: GIDSignInResult?, error: Error?) async {
        if let error = error as NSError? {
            if error.code == -5 { // User cancelled
                updateState(.guest)
                return
            }
            let isNetworkError = error.domain == NSURLErrorDomain
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
            let nsError = error as NSError
            let isNetworkError = nsError.domain == NSURLErrorDomain
            updateState(.error(
                message: isNetworkError ? "offline" : "error",
                retryable: true
            ))
        }
    }
    
    // MARK: - Sign In with Apple
    
    func signInWithApple() {
        guard case .guest = state else { return }
        
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
    
    func deleteAccount(presentingViewController: UIViewController) async throws {
        guard case .signedIn(let user) = state else { return }
        
        updateState(.deleting)
        
        guard let currentUser = Auth.auth().currentUser else {
            updateState(.error(message: "error", retryable: true))
            return
        }
        
        // Проверяем, нужна ли повторная авторизация
        let needsReauth = await checkIfReauthNeeded()
        
        if needsReauth {
            // Запрашиваем повторную авторизацию
            do {
                try await reauthenticate(user: user, presentingViewController: presentingViewController)
            } catch {
                updateState(.signedIn(user: user))
                throw error
            }
        }
        
        // Отзываем Apple токены если это Apple
        if user.provider == "apple" {
            await revokeAppleToken()
        }
        
        // Удаляем аккаунт
        do {
            try await currentUser.delete()
            // Состояние обновится через authStateListener
        } catch {
            updateState(.signedIn(user: user))
            throw error
        }
    }
    
    private func checkIfReauthNeeded() async -> Bool {
        guard let metadata = Auth.auth().currentUser?.metadata else { return true }
        guard let lastSignIn = metadata.lastSignInDate else { return true }
        
        // Требуем повторную авторизацию если последний вход был более 5 минут назад
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        return lastSignIn < fiveMinutesAgo
    }
    
    private func reauthenticate(user: AuthUser, presentingViewController: UIViewController) async throws {
        if user.provider == "google" {
            try await reauthenticateWithGoogle(presentingViewController: presentingViewController)
        } else if user.provider == "apple" {
            try await reauthenticateWithApple()
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
                        try await Auth.auth().currentUser?.reauthenticate(with: credential)
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
    
    private func revokeAppleToken() async {
        guard let authorizationCode = Auth.auth().currentUser?.providerData
            .first(where: { $0.providerID == "apple.com" })?
            .uid else { return }
        
        // Best effort revocation
        try? await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
    }
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
            
            if appleReauthContinuation != nil {
                appleReauthContinuation?.resume(throwing: NSError(domain: "AuthCoordinator", code: -3, userInfo: [NSLocalizedDescriptionKey: "Apple authorization failed"]))
                appleReauthContinuation = nil
            } else {
                updateState(.error(message: "error", retryable: true))
            }
            return
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        do {
            if appleReauthContinuation != nil {
                // Повторная авторизация
                try await Auth.auth().currentUser?.reauthenticate(with: credential)
                appleReauthContinuation?.resume()
                appleReauthContinuation = nil
            } else {
                // Первичный вход
                _ = try await Auth.auth().signIn(with: credential)
                // Состояние обновится через authStateListener
            }
        } catch {
            if appleReauthContinuation != nil {
                appleReauthContinuation?.resume(throwing: error)
                appleReauthContinuation = nil
            } else {
                let nsError = error as NSError
                let isNetworkError = nsError.domain == NSURLErrorDomain
                updateState(.error(
                    message: isNetworkError ? "offline" : "error",
                    retryable: true
                ))
            }
        }
    }
    
    private func handleAppleError(_ error: Error) {
        let nsError = error as NSError
        
        if appleReauthContinuation != nil {
            appleReauthContinuation?.resume(throwing: error)
            appleReauthContinuation = nil
            return
        }
        
        if nsError.code == 1001 { // User cancelled
            updateState(.guest)
            return
        }
        
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
