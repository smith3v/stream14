import Foundation
import Testing
import UIKit
import GoogleSignIn
import AppAuth
@testable import Stream14

@MainActor struct YouTubeAuthorizationTests {
    private let good = GoogleAuthorizationAccount(id: "fixture-account", grantedScopes: [YouTubeAuthorization.requiredScope])

    @Test func consentBlocksSDKUntilExplicitAgreementAndPersistsOnlyChoice() async {
        let driver = FakeGoogleAuthorizationDriver()
        driver.result = good
        var choices: [Bool] = []
        let auth = YouTubeAuthorization(driver: driver, configured: true,
            savePolicyAcceptance: { choices.append($0) })
        await auth.connect(presenting: UIViewController())
        await auth.restore()
        #expect(driver.connectCalls == 0 && !auth.isAuthorized)
        #expect(choices.isEmpty)
        auth.acceptYouTubePolicy()
        await auth.connect(presenting: UIViewController())
        #expect(driver.connectCalls == 1 && auth.isAuthorized)
        #expect(choices == [true])
    }

    @Test func launchRestoreWaitsForConsentAndAccountUnlockAndUsesOnlySavedAuthorization() async {
        let driver = FakeGoogleAuthorizationDriver()
        driver.result = good
        let auth = YouTubeAuthorization(driver: driver, configured: true)
        await auth.restoreOnLaunchIfAvailable(broadcastActive: false)
        auth.acceptYouTubePolicy()
        await auth.restoreOnLaunchIfAvailable(broadcastActive: true)
        #expect(driver.savedSignInChecks == 0 && driver.restoreCalls == 0)

        await auth.restoreOnLaunchIfAvailable(broadcastActive: false)
        await auth.restoreOnLaunchIfAvailable(broadcastActive: false)
        #expect(auth.isAuthorized && auth.account == good)
        #expect(driver.savedSignInChecks == 1 && driver.restoreCalls == 1 && driver.connectCalls == 0)
    }

    @Test func launchWithoutSavedSignInLeavesTheManualConnectionAvailable() async {
        let driver = FakeGoogleAuthorizationDriver()
        driver.hasSavedSignIn = false
        driver.result = good
        let unconfigured = YouTubeAuthorization(driver: driver, configured: false, policyAccepted: true)
        await unconfigured.restoreOnLaunchIfAvailable(broadcastActive: false)
        #expect(driver.savedSignInChecks == 0)

        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        let message = auth.message
        await auth.restoreOnLaunchIfAvailable(broadcastActive: false)
        await auth.restoreOnLaunchIfAvailable(broadcastActive: false)
        #expect(auth.message == message && !auth.isWorking && !auth.isAuthorized)
        #expect(driver.savedSignInChecks == 1 && driver.restoreCalls == 0)
        await auth.connect(presenting: UIViewController())
        #expect(driver.connectCalls == 1 && auth.isAuthorized)
    }

    @Test func launchRestoreFailurePreservesSavedSignInAndOffersManualConnection() async {
        let driver = FakeGoogleAuthorizationDriver()
        driver.result = good
        driver.failure = .unavailable
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        var erasures = 0
        auth.onDeleteAPIData = { erasures += 1; return true }
        await auth.restoreOnLaunchIfAvailable(broadcastActive: false)
        await auth.restoreOnLaunchIfAvailable(broadcastActive: false)
        #expect(erasures == 0 && driver.signOutCalls == 0)
        #expect(!auth.isAuthorized && !auth.isWorking && auth.message.contains("try again"))
        #expect(driver.restoreCalls == 1 && driver.connectCalls == 0)
        driver.failure = nil
        await auth.connect(presenting: UIViewController())
        #expect(driver.connectCalls == 1 && auth.isAuthorized)
    }

    @Test func launchRestoreErasesSavedDataOnDefinitiveAccessLoss() async {
        for failure in [YouTubeAuthorizationError.authorizationRequired, nil] {
            let driver = FakeGoogleAuthorizationDriver()
            driver.failure = failure // The default account omits the required YouTube scope.
            let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
            var erasures = 0
            auth.onDeleteAPIData = { erasures += 1; return true }
            await auth.restoreOnLaunchIfAvailable(broadcastActive: false)
            #expect(erasures == 1 && driver.signOutCalls == 1)
            #expect(!auth.isAuthorized && !auth.isWorking)
        }
    }

    @Test func launchRestoreSerializesWorkAndDiscardsCallbackAfterSignOut() async {
        let driver = FakeGoogleAuthorizationDriver()
        driver.result = good
        driver.holdRestore = true
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        let operation = Task { await auth.restoreOnLaunchIfAvailable(broadcastActive: false) }
        while driver.pending == nil { await Task.yield() }
        await auth.restoreOnLaunchIfAvailable(broadcastActive: false)
        await auth.connect(presenting: UIViewController())
        #expect(driver.restoreCalls == 1 && driver.connectCalls == 0)
        auth.signOut()
        driver.completeConnection()
        await operation.value
        await auth.restoreOnLaunchIfAvailable(broadcastActive: false)
        #expect(!auth.isAuthorized && !auth.isWorking && auth.message.contains("Signed out"))
        #expect(driver.restoreCalls == 1 && driver.signOutCalls == 2)
    }

    @Test func explicitSignOutSupersedesLaunchRestore() async {
        let driver = FakeGoogleAuthorizationDriver()
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        auth.signOut()
        await auth.restoreOnLaunchIfAvailable(broadcastActive: false)
        #expect(driver.savedSignInChecks == 0 && driver.restoreCalls == 0)
    }

    @Test func signOutRetainsJournalsButDeletionRevokeAndDetectedAccessLossRequestErasure() async {
        let driver = FakeGoogleAuthorizationDriver(); driver.result = good
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        var erasures = 0
        auth.onDeleteAPIData = { erasures += 1; return true }
        await auth.restore(); auth.signOut()
        #expect(erasures == 0)
        auth.deleteYouTubeData()
        #expect(erasures == 1 && !auth.isAuthorized)
        await auth.restore(); await auth.disconnect()
        #expect(erasures == 2 && auth.message.contains("revoked"))
        await auth.restore(); driver.failure = .authorizationRequired
        await #expect(throws: YouTubeAuthorizationError.authorizationRequired) {
            try await auth.freshAccessToken(expectedGeneration: auth.generation)
        }
        #expect(erasures == 3)
        driver.failure = nil; await auth.restore(); auth.accessWasDenied()
        #expect(erasures == 4 && !auth.isAuthorized)
    }

    @Test func offlineRestorePreservesNonexpiredPendingIntentAndNeverClaimsRevocation() async {
        let driver = FakeGoogleAuthorizationDriver()
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("offline-restore-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PendingBroadcastIntentStore(directory: directory)
        let intent = PendingBroadcastIntent(channelID: "invented-channel", broadcastID: "invented-event", profile: .hd)
        try? store.save(intent)
        var erasures = 0
        auth.onDeleteAPIData = { erasures += 1; return (try? store.eraseAPIData()) != nil }
        driver.failure = .unavailable
        await auth.restore()
        #expect(erasures == 0 && !auth.isAuthorized)
        #expect((try? store.load()) == intent)
        #expect(!auth.message.contains("revoked"))
        driver.failure = .cancelled
        await auth.restore()
        #expect(erasures == 0)
        driver.failure = .noPreviousSignIn
        await auth.restore()
        #expect(erasures == 0 && (try? store.load()) == intent)
        driver.failure = .authorizationRequired
        await auth.restore()
        #expect(erasures == 1 && store.requiresStudioResolution)
    }

    @Test func deletionFailureIsVisibleAndNeverReportedAsSuccess() {
        let auth = YouTubeAuthorization(driver: FakeGoogleAuthorizationDriver(), configured: true, policyAccepted: true)
        auth.onDeleteAPIData = { false }
        auth.deleteYouTubeData()
        #expect(auth.message.contains("failed"))
    }

    @Test func SDKClassificationDistinguishesOfflineAndConfirmedGrantLoss() {
        #expect(GoogleAuthorizationDriver.safeError(URLError(.notConnectedToInternet)) == .unavailable)
        #expect(GoogleAuthorizationDriver.safeError(URLError(.cancelled)) == .cancelled)
        #expect(GoogleAuthorizationDriver.safeError(NSError(domain: kGIDSignInErrorDomain,
            code: GIDSignInError.refreshTokenExpired.rawValue)) == .authorizationRequired)
        #expect(GoogleAuthorizationDriver.safeError(NSError(domain: OIDOAuthTokenErrorDomain,
            code: OIDErrorCodeOAuthToken.invalidGrant.rawValue)) == .authorizationRequired)
    }

    @Test func offlineTokenRefreshRetainsAuthorizationGenerationAndPendingContext() async throws {
        let driver = FakeGoogleAuthorizationDriver(); driver.result = good
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        var erasures = 0
        auth.onDeleteAPIData = { erasures += 1; return true }
        await auth.restore()
        let generation = auth.generation
        driver.failure = .unavailable
        await #expect(throws: YouTubeAuthorizationError.unavailable) {
            try await auth.freshAccessToken(expectedGeneration: generation)
        }
        #expect(erasures == 0 && auth.isAuthorized && auth.generation == generation)
    }

    @Test func configurationRequiresMatchingCallbackAndIOSClient() {
        #expect(GoogleAuthorizationConfiguration(info: [:]) == nil)
        #expect(GoogleAuthorizationConfiguration(info: ["GIDClientID": "fixture.apps.googleusercontent.com"]) == nil)
        let info: [String: Any] = ["GIDClientID": "fixture.apps.googleusercontent.com",
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["com.googleusercontent.apps.fixture"]]]]
        #expect(GoogleAuthorizationConfiguration(info: info)?.callbackScheme == "com.googleusercontent.apps.fixture")
        var malformed = info
        malformed["GIDClientID"] = "fixture.extra.apps.googleusercontent.com"
        #expect(GoogleAuthorizationConfiguration(info: malformed) == nil)
    }

    @Test func missingConfigurationNeverCallsSDK() async {
        let driver = FakeGoogleAuthorizationDriver()
        let auth = YouTubeAuthorization(driver: driver, configured: false)
        await auth.connect(presenting: UIViewController())
        await auth.restore()
        #expect(driver.connectCalls == 0)
        #expect(!auth.isAuthorized)
    }

    @Test func cancellationAndDeniedScopeStayDisconnected() async {
        let driver = FakeGoogleAuthorizationDriver()
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        driver.failure = .cancelled
        await auth.connect(presenting: UIViewController())
        #expect(auth.message.contains("cancelled"))
        driver.failure = nil
        driver.result = GoogleAuthorizationAccount(id: "fixture", grantedScopes: [])
        await auth.connect(presenting: UIViewController())
        #expect(!auth.isAuthorized)
        #expect(auth.message.contains("permission"))
        #expect(driver.signOutCalls == 2)
    }

    @Test func switchingAndSigningOutInvalidateDependentGenerations() async {
        let driver = FakeGoogleAuthorizationDriver()
        driver.result = good
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        await auth.connect(presenting: UIViewController())
        let first = auth.generation
        #expect(auth.isAuthorized)
        await auth.connect(presenting: UIViewController())
        #expect(auth.generation != first)
        let second = auth.generation
        auth.signOut()
        #expect(auth.generation != second)
        #expect(auth.account == nil)
        await #expect(throws: YouTubeAuthorizationError.authorizationRequired) {
            try await auth.freshAccessToken(expectedGeneration: first)
        }
    }

    @Test func refreshFailureClearsReadinessAndDoesNotExposeServerErrors() async {
        let driver = FakeGoogleAuthorizationDriver()
        driver.result = good
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        await auth.restore()
        let generation = auth.generation
        driver.failure = .authorizationRequired
        await #expect(throws: YouTubeAuthorizationError.authorizationRequired) {
            try await auth.freshAccessToken(expectedGeneration: generation)
        }
        #expect(auth.generation != generation)
        #expect(!auth.isAuthorized)
        #expect(auth.message.contains("refreshed"))
    }

    @Test func lateConnectionAfterSignOutCannotRestoreAccount() async {
        let driver = FakeGoogleAuthorizationDriver()
        driver.result = good
        driver.holdConnection = true
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        let operation = Task { await auth.connect(presenting: UIViewController()) }
        while driver.pending == nil { await Task.yield() }
        auth.signOut()
        #expect(auth.isWorking)
        await auth.connect(presenting: UIViewController()) // serialized until old SDK callback
        #expect(driver.connectCalls == 1)
        driver.completeConnection()
        await operation.value
        #expect(!auth.isAuthorized)
        #expect(!auth.isWorking)
        #expect(auth.message.contains("Signed out"))
    }

    @Test func cancelledTaskCannotRestoreAccount() async {
        let driver = FakeGoogleAuthorizationDriver()
        driver.result = good
        driver.holdConnection = true
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        let operation = Task { await auth.connect(presenting: UIViewController()) }
        while driver.pending == nil { await Task.yield() }
        operation.cancel()
        driver.completeConnection()
        await operation.value
        #expect(!auth.isAuthorized)
        #expect(auth.message.contains("cancelled"))
    }

    @Test func revokeFailureIsHonestAndBroadcastGuardPreservesAccount() async {
        let driver = FakeGoogleAuthorizationDriver()
        driver.result = good
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        await auth.restore()
        let generation = auth.generation
        auth.signOut(broadcastActive: true)
        await auth.connect(presenting: UIViewController(), broadcastActive: true)
        await auth.disconnect(broadcastActive: true)
        #expect(auth.generation == generation)
        #expect(auth.isAuthorized)
        driver.failure = .unavailable
        await auth.disconnect()
        #expect(!auth.isAuthorized)
        #expect(auth.message.contains("could not be revoked"))
    }


    @Test func cancelledTokenReadPreservesAuthorization() async {
        let driver = FakeGoogleAuthorizationDriver()
        driver.result = good
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        await auth.restore()
        let generation = auth.generation
        driver.holdToken = true
        let read = Task { try await auth.freshAccessToken(expectedGeneration: generation) }
        while driver.pendingToken == nil { await Task.yield() }
        read.cancel()
        driver.completeToken()
        await #expect(throws: YouTubeAuthorizationError.cancelled) { try await read.value }
        #expect(auth.generation == generation)
        #expect(auth.isAuthorized)
    }

    @Test func tokenArrivingAfterSignOutIsDiscarded() async {
        let driver = FakeGoogleAuthorizationDriver()
        driver.result = good
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        await auth.restore()
        let generation = auth.generation
        driver.holdToken = true
        let read = Task { try await auth.freshAccessToken(expectedGeneration: generation) }
        while driver.pendingToken == nil { await Task.yield() }
        auth.signOut()
        driver.completeToken()
        await #expect(throws: YouTubeAuthorizationError.cancelled) { try await read.value }
        #expect(!auth.isAuthorized)
    }

    @Test func refreshSucceedsOnlyForCurrentGenerationAndDoesNotPersistToken() async throws {
        let driver = FakeGoogleAuthorizationDriver()
        driver.result = good
        let auth = YouTubeAuthorization(driver: driver, configured: true, policyAccepted: true)
        await auth.restore()
        let token = try await auth.freshAccessToken(expectedGeneration: auth.generation)
        #expect(token == "fixture-access-token")
        #expect(auth.account == good)
        #expect(!auth.message.contains(token))
        await auth.disconnect()
        #expect(auth.message.contains("revoked"))
        #expect(auth.account == nil)
    }
}

@MainActor private final class FakeGoogleAuthorizationDriver: GoogleAuthorizationDriving {
    var result = GoogleAuthorizationAccount(id: "fixture", grantedScopes: [])
    var failure: YouTubeAuthorizationError?
    var signOutCalls = 0
    var connectCalls = 0
    var restoreCalls = 0
    var savedSignInChecks = 0
    var hasSavedSignIn = true
    var hasPreviousSignIn: Bool {
        savedSignInChecks += 1
        return hasSavedSignIn
    }
    var holdConnection = false
    var holdRestore = false
    var holdToken = false
    var pendingToken: CheckedContinuation<String, any Error>?
    func completeToken() { let callback = pendingToken; pendingToken = nil; callback?.resume(returning: "fixture-access-token") }
    var pending: CheckedContinuation<GoogleAuthorizationAccount, any Error>?
    func connect(presenting: UIViewController) async throws -> GoogleAuthorizationAccount {
        connectCalls += 1
        if holdConnection { return try await withCheckedThrowingContinuation { pending = $0 } }
        if let failure { throw failure }
        return result
    }
    func completeConnection() { let callback = pending; pending = nil; callback?.resume(returning: result) }
    func restore() async throws -> GoogleAuthorizationAccount {
        restoreCalls += 1
        if holdRestore { return try await withCheckedThrowingContinuation { pending = $0 } }
        if let failure { throw failure }
        return result
    }
    func accessToken(accountID: String) async throws -> String {
        if holdToken { return try await withCheckedThrowingContinuation { pendingToken = $0 } }
        if let failure { throw failure }
        return "fixture-access-token"
    }
    func signOut() { signOutCalls += 1 }
    func disconnect() async throws { if let failure { throw failure } }
    func handle(_ url: URL) -> Bool { false }
}
