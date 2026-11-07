import GoogleSignIn
import UIKit

/// Google's SDK alone owns persisted credentials and supported system-browser authorization.
@MainActor final class GoogleAuthorizationDriver: GoogleAuthorizationDriving {
    private let configuration: GoogleAuthorizationConfiguration
    private let sdk = GIDSignIn.sharedInstance

    init(configuration: GoogleAuthorizationConfiguration) {
        self.configuration = configuration
        sdk.configuration = GIDConfiguration(clientID: configuration.clientID)
    }

    func connect(presenting: UIViewController) async throws -> GoogleAuthorizationAccount {
        // No hint forces the supported account-selection flow after local sign-out.
        sdk.signOut()
        return try await withCheckedThrowingContinuation { continuation in
            sdk.signIn(withPresenting: presenting, hint: nil,
                       additionalScopes: [YouTubeAuthorization.requiredScope]) { result, error in
                Task { @MainActor in
                    if let error { continuation.resume(throwing: Self.safeError(error)); return }
                    guard let user = result?.user else {
                        continuation.resume(throwing: YouTubeAuthorizationError.unavailable); return
                    }
                    continuation.resume(returning: Self.account(user))
                }
            }
        }
    }

    func restore() async throws -> GoogleAuthorizationAccount {
        guard sdk.hasPreviousSignIn() else { throw YouTubeAuthorizationError.noPreviousSignIn }
        return try await withCheckedThrowingContinuation { continuation in
            sdk.restorePreviousSignIn { user, error in
                Task { @MainActor in
                    if let error { continuation.resume(throwing: Self.safeError(error)); return }
                    guard let user else { continuation.resume(throwing: YouTubeAuthorizationError.unavailable); return }
                    continuation.resume(returning: Self.account(user))
                }
            }
        }
    }

    func accessToken(accountID: String) async throws -> String {
        guard let user = sdk.currentUser, user.userID == accountID else {
            throw YouTubeAuthorizationError.authorizationRequired
        }
        return try await withCheckedThrowingContinuation { continuation in
            user.refreshTokensIfNeeded { [weak self] refreshed, error in
                Task { @MainActor in
                    guard error == nil, let refreshed,
                          refreshed.userID == accountID, self?.sdk.currentUser?.userID == accountID,
                          Set(refreshed.grantedScopes ?? []).contains(YouTubeAuthorization.requiredScope) else {
                        continuation.resume(throwing: YouTubeAuthorizationError.authorizationRequired); return
                    }
                    continuation.resume(returning: refreshed.accessToken.tokenString)
                }
            }
        }
    }

    func signOut() { sdk.signOut() }
    func disconnect() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            sdk.disconnect { error in
                if error != nil { continuation.resume(throwing: YouTubeAuthorizationError.unavailable) }
                else { continuation.resume() }
            }
        }
    }
    func handle(_ url: URL) -> Bool {
        guard url.scheme == configuration.callbackScheme else { return false }
        return sdk.handle(url)
    }

    private static func account(_ user: GIDGoogleUser) -> GoogleAuthorizationAccount {
        GoogleAuthorizationAccount(id: user.userID ?? "", grantedScopes: Set(user.grantedScopes ?? []))
    }

    private static func safeError(_ error: any Error) -> YouTubeAuthorizationError {
        let ns = error as NSError
        guard ns.domain == kGIDSignInErrorDomain else { return .unavailable }
        switch ns.code {
        case GIDSignInErrorCode.canceled.rawValue: return .cancelled
        case GIDSignInErrorCode.hasNoAuthInKeychain.rawValue: return .noPreviousSignIn
        default: return .unavailable
        }
    }
}
