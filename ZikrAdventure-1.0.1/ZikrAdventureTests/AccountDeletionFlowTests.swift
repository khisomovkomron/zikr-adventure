// AccountDeletionFlowTests.swift
// ZKR-56: порядок reauth → (Apple) отзыв → удаление; при ошибке отзыва аккаунт не удаляется.

import XCTest
@testable import ZikrAdventure

@MainActor
private final class FakeDeletionBackend: AccountDeletionBackend {
    var steps: [String] = []
    var reauthResult: Result<String?, Error> = .success("code")
    var revokeError: Error?
    var deleteError: Error?

    func reauthenticate(provider: String) async throws -> String? {
        steps.append("reauth:\(provider)")
        return try reauthResult.get()
    }

    func revokeAppleToken(authorizationCode: String) async throws {
        steps.append("revoke")
        if let revokeError { throw revokeError }
    }

    func deleteUser() async throws {
        steps.append("delete")
        if let deleteError { throw deleteError }
    }
}

@MainActor
final class AccountDeletionFlowTests: XCTestCase {
    private let google = AuthUser(uid: "g", displayName: nil, email: nil, provider: "google")

    private func run(_ backend: FakeDeletionBackend, user: AuthUser) async -> (AccountDeletionOutcome, [AuthState]) {
        var states: [AuthState] = []
        let outcome = await AccountDeletionFlow(backend: backend).run(user: user) { states.append($0) }
        return (outcome, states)
    }

    func testAppleHappyPathRevokesBeforeDelete() async {
        let backend = FakeDeletionBackend()
        let (outcome, states) = await run(backend, user: signedInAppleUser)
        XCTAssertEqual(outcome, .deleted)
        XCTAssertEqual(backend.steps, ["reauth:apple", "revoke", "delete"])
        XCTAssertEqual(states, [.error(message: "reauth", retryable: false), .deleting, .guest])
    }

    func testGoogleSkipsRevoke() async {
        let backend = FakeDeletionBackend()
        backend.reauthResult = .success(nil)
        let (outcome, _) = await run(backend, user: google)
        XCTAssertEqual(outcome, .deleted)
        XCTAssertEqual(backend.steps, ["reauth:google", "delete"])
    }

    func testRevokeFailureKeepsAccount() async {
        let backend = FakeDeletionBackend()
        backend.revokeError = NSError(domain: "AppleRevoke", code: 1)
        let (outcome, states) = await run(backend, user: signedInAppleUser)
        XCTAssertEqual(outcome, .revokeFailed)
        XCTAssertFalse(backend.steps.contains("delete"))
        XCTAssertEqual(states.last, .signedIn(user: signedInAppleUser))
    }

    func testMissingAppleCodeKeepsAccount() async {
        let backend = FakeDeletionBackend()
        backend.reauthResult = .success(nil)
        let (outcome, _) = await run(backend, user: signedInAppleUser)
        XCTAssertEqual(outcome, .revokeFailed)
        XCTAssertEqual(backend.steps, ["reauth:apple"])
    }

    func testRevokeNetworkErrorIsOffline() async {
        let backend = FakeDeletionBackend()
        backend.revokeError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let (outcome, _) = await run(backend, user: signedInAppleUser)
        XCTAssertEqual(outcome, .offline)
    }

    func testCancelledReauthReturnsToSignedIn() async {
        let backend = FakeDeletionBackend()
        backend.reauthResult = .failure(NSError(domain: AuthErrorClassifier.appleDomain, code: AuthErrorClassifier.appleCanceledCode))
        let (outcome, states) = await run(backend, user: signedInAppleUser)
        XCTAssertEqual(outcome, .cancelled)
        XCTAssertFalse(outcome.isIssue)
        XCTAssertNil(outcome.webMessage)
        XCTAssertEqual(states.last, .signedIn(user: signedInAppleUser))
    }

    func testDeleteFailure() async {
        let backend = FakeDeletionBackend()
        backend.deleteError = NSError(domain: AuthErrorClassifier.firebaseAuthDomain, code: 17014)
        let (outcome, _) = await run(backend, user: google)
        XCTAssertEqual(outcome, .failed)
        XCTAssertEqual(outcome.webMessage, "error")
    }

    func testClassifier() {
        XCTAssertEqual(AuthErrorClassifier.classify(NSError(domain: AuthErrorClassifier.googleDomain, code: -5)), .cancelled)
        XCTAssertEqual(AuthErrorClassifier.classify(NSError(domain: AuthErrorClassifier.firebaseAuthDomain, code: 17020)), .network)
        let wrapped = NSError(domain: "X", code: 1, userInfo: [NSUnderlyingErrorKey: NSError(domain: NSURLErrorDomain, code: -1009)])
        XCTAssertEqual(AuthErrorClassifier.classify(wrapped), .network)
        XCTAssertEqual(AuthErrorClassifier.classify(NSError(domain: AuthErrorClassifier.googleDomain, code: -4)), .other)
    }
}
