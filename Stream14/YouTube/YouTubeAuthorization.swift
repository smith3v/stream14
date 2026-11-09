import Foundation
import Observation
import UIKit

struct GoogleAuthorizationConfiguration: Equatable {
    let clientID: String
    let callbackScheme: String

    init?(info: [String: Any]) {
        guard let id = info["GIDClientID"] as? String,
              id.hasSuffix(".apps.googleusercontent.com"),
              !id.contains("$"), !id.contains(where: \.isWhitespace),
              id.count > ".apps.googleusercontent.com".count else { return nil }
        let prefix = String(id.dropLast(".apps.googleusercontent.com".count))
        guard prefix.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-").contains($0) }) else { return nil }
        let callback = "com.googleusercontent.apps." + prefix
        let types = info["CFBundleURLTypes"] as? [[String: Any]] ?? []
        guard types.contains(where: { ($0["CFBundleURLSchemes"] as? [String] ?? []).contains(callback) }) else { return nil }
        clientID = id
        callbackScheme = callback
    }
}

struct GoogleAuthorizationAccount: Equatable, Sendable {
    let id: String
    let grantedScopes: Set<String>
}

// Only this test seam hides the SDK; no app-owned credential storage is introduced.
@MainActor protocol GoogleAuthorizationDriving {
    func connect(presenting: UIViewController) async throws -> GoogleAuthorizationAccount
    func restore() async throws -> GoogleAuthorizationAccount
    func accessToken(accountID: String) async throws -> String
    func signOut()
    func disconnect() async throws
    func handle(_ url: URL) -> Bool
}

enum YouTubeAuthorizationError: Error, Equatable {
    case cancelled, noPreviousSignIn, missingScope, authorizationRequired, unavailable
}

@MainActor @Observable final class YouTubeAuthorization {
    static let requiredScope = "https://www.googleapis.com/auth/youtube.force-ssl"
    private(set) var account: GoogleAuthorizationAccount?
    private(set) var generation: UInt64 = 0
    private(set) var isWorking = false
    private(set) var message: String
    private(set) var policyAccepted: Bool
    @ObservationIgnored private let savePolicyAcceptance: (Bool) -> Void
    @ObservationIgnored var onDeleteAPIData: (() -> Bool)?
    private func clearAPIData() -> Bool { onDeleteAPIData?() ?? true }
    let isConfigured: Bool
    @ObservationIgnored private let driver: (any GoogleAuthorizationDriving)?

    init(driver: (any GoogleAuthorizationDriving)?, configured: Bool, policyAccepted: Bool = false,
         savePolicyAcceptance: @escaping (Bool) -> Void = { _ in }) {
        self.policyAccepted = policyAccepted
        self.savePolicyAcceptance = savePolicyAcceptance
        self.driver = driver
        isConfigured = configured
        message = configured ? "YouTube is disconnected. Local recording is available." :
            "YouTube setup is needed. Configure the Google iOS client; local recording is available."
    }

    #if DEBUG
    static func interfaceFixture() -> YouTubeAuthorization {
        let value = YouTubeAuthorization(driver: nil, configured: true, policyAccepted: true)
        value.account = GoogleAuthorizationAccount(id: "fixture-account", grantedScopes: [requiredScope])
        value.message = "Fixture YouTube connection. No Google requests."
        return value
    }
    #endif

    convenience init(bundle: Bundle = .main) {
        let config = GoogleAuthorizationConfiguration(info: bundle.infoDictionary ?? [:])
        self.init(driver: config.map { GoogleAuthorizationDriver(configuration: $0) }, configured: config != nil,
            policyAccepted: UserDefaults.standard.bool(forKey: "YouTubePolicy20261109"),
            savePolicyAcceptance: { UserDefaults.standard.set($0, forKey: "YouTubePolicy20261109") })
    }

    var isAuthorized: Bool { policyAccepted && account != nil && !isWorking }

    func acceptYouTubePolicy() {
        policyAccepted = true
        savePolicyAcceptance(true)
    }

    /// Local deletion is distinct from remote revocation and never deletes media.
    func deleteYouTubeData(broadcastActive: Bool = false) {
        guard !broadcastActive, !isWorking else { return }
        invalidate(); driver?.signOut()
        message = clearAPIData() ? "YouTube data deleted locally. Google access is unchanged; review Google Account permissions to revoke it." :
            "YouTube data deletion failed. Publishing is blocked; resolve local storage and retry deletion."
    }

    func accessWasDenied(expectedGeneration: UInt64? = nil) {
        if let expectedGeneration, expectedGeneration != generation { return }
        invalidate(); driver?.signOut()
        message = clearAPIData() ? "YouTube authorization is unavailable. Saved YouTube API data was cleared; check Google access and YouTube Studio before reconnecting." :
            "YouTube authorization is unavailable and local data deletion failed. Resolve local storage and retry deletion."
    }

    func connect(presenting: UIViewController, broadcastActive: Bool = false) async {
        guard begin(broadcastActive: broadcastActive), let driver else { return }
        let operation = generation
        defer { isWorking = false }
        do {
            let result = try await driver.connect(presenting: presenting)
            try accept(result, operation: operation)
        } catch { finish(error, operation: operation) }
    }

    func restore(broadcastActive: Bool = false) async {
        guard begin(broadcastActive: broadcastActive), let driver else { return }
        let operation = generation
        defer { isWorking = false }
        do {
            let result = try await driver.restore()
            try accept(result, operation: operation)
        } catch { finish(error, operation: operation) }
    }

    func signOut(broadcastActive: Bool = false) {
        guard !broadcastActive else { message = "End the broadcast before changing YouTube accounts."; return }
        // Invalidate even a pending result, but keep SDK operations serialized until its callback.
        invalidate()
        driver?.signOut()
        message = "Signed out on this iPhone. Google access has not been revoked."
    }

    func disconnect(broadcastActive: Bool = false) async {
        guard begin(broadcastActive: broadcastActive), let driver else { return }
        let operation = generation
        defer { isWorking = false }
        do {
            try await driver.disconnect()
            guard operation == generation else { return }
            driver.signOut()
            message = clearAPIData() ? "Google access revoked and local YouTube data deleted. Recordings and overlay settings remain." :
                "Google access revoked, but local YouTube data deletion failed. Resolve local storage and retry deletion."
        } catch {
            guard operation == generation else { return }
            _ = clearAPIData()
            // A failed revoke must not be reported as revoked. Keep local state clear.
            driver.signOut()
            message = "Signed out locally. Google access could not be revoked; check your Google Account permissions and retry connecting if needed."
        }
    }

    /// F3 supplies this generation with each request and discards responses after a change.
    func freshAccessToken(expectedGeneration: UInt64) async throws -> String {
        guard !isWorking, expectedGeneration == generation, let account, let driver else {
            throw YouTubeAuthorizationError.authorizationRequired
        }
        do {
            let token = try await driver.accessToken(accountID: account.id)
            guard expectedGeneration == generation, self.account?.id == account.id, !Task.isCancelled else {
                throw YouTubeAuthorizationError.cancelled
            }
            return token
        } catch {
            if Task.isCancelled || error is CancellationError || error as? YouTubeAuthorizationError == .cancelled {
                throw YouTubeAuthorizationError.cancelled
            }
            if expectedGeneration == generation {
                invalidate()
                driver.signOut()
                _ = clearAPIData()
                message = "YouTube authorization expired or could not be refreshed. Connect again."
            }
            throw YouTubeAuthorizationError.authorizationRequired
        }
    }

    @discardableResult func handle(_ url: URL) -> Bool { driver?.handle(url) ?? false }

    private func begin(broadcastActive: Bool) -> Bool {
        guard !broadcastActive else { message = "End the broadcast before changing YouTube accounts."; return false }
        guard policyAccepted else {
            message = "Read and agree to the privacy policy and YouTube terms before connecting. Local recording remains available."
            return false
        }
        guard isConfigured, driver != nil, !isWorking else { return false }
        invalidate()
        isWorking = true
        message = "Connecting YouTube…"
        return true
    }

    private func invalidate() { generation &+= 1; account = nil }

    private func accept(_ result: GoogleAuthorizationAccount, operation: UInt64) throws {
        guard operation == generation, !Task.isCancelled else {
            driver?.signOut()
            throw YouTubeAuthorizationError.cancelled
        }
        guard !result.id.isEmpty, result.grantedScopes.contains(Self.requiredScope) else {
            throw YouTubeAuthorizationError.missingScope
        }
        account = result
        message = "Google authorized. YouTube channel identity will be checked before selecting an event."
    }

    private func finish(_ error: any Error, operation: UInt64) {
        guard operation == generation else { driver?.signOut(); return }
        driver?.signOut()
        account = nil
        // Unknown/network restore errors retain exact reconciliation context.
        // Only explicit SDK loss classifications erase API-derived identifiers.
        if [.authorizationRequired, .missingScope].contains(error as? YouTubeAuthorizationError) {
            _ = clearAPIData()
        }
        switch error as? YouTubeAuthorizationError {
        case .cancelled: message = "YouTube connection cancelled. Local recording is available."
        case .noPreviousSignIn: message = "No saved Google authorization. Connect YouTube to continue."
        case .missingScope: message = "YouTube permission was not granted. Connect again and allow YouTube access."
        default: message = "YouTube authorization failed. Check Google setup and your connection, then try again."
        }
    }
}
