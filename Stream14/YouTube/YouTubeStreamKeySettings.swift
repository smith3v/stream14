import Foundation
import Observation
import Security

/// Keep credentials out of reflection and encoders other than the Keychain store.
nonisolated struct SavedYouTubeStreamKey: Sendable, CustomReflectable {
    let destination: YouTubeIngestionDestination
    var customMirror: Mirror { Mirror(self, children: ["credentials": "<redacted>"]) }

    init(key: String) throws {
        let streamName = key.trimmingCharacters(in: .whitespacesAndNewlines)
        // Accept a key pasted from Studio, with no URL or path components.
        guard !streamName.isEmpty, streamName.utf8.allSatisfy({
            (48...57).contains($0) || (65...90).contains($0) ||
            (97...122).contains($0) || $0 == 45 || $0 == 95
        }) else { throw YouTubeBindingError.invalidDestination }
        destination = try YouTubeIngestionDestination(
            address: "rtmps://a.rtmps.youtube.com:443/live2", streamName: streamName)
    }
}

@MainActor @Observable final class YouTubeStreamKeySettings {
    private(set) var saved: SavedYouTubeStreamKey?
    private(set) var feedback: String?
    private var readFailed = false
    private let read: () throws -> SavedYouTubeStreamKey?
    private let write: (SavedYouTubeStreamKey?) throws -> Void

    init(read: @escaping () throws -> SavedYouTubeStreamKey? = { nil },
         write: @escaping (SavedYouTubeStreamKey?) throws -> Void = { _ in }) {
        self.read = read
        self.write = write
        reload()
    }

    static func deviceSettings() -> YouTubeStreamKeySettings {
        YouTubeStreamKeySettings(read: YouTubeStreamKeyStore.read, write: YouTubeStreamKeyStore.write)
    }

    func retryReadIfNeeded() {
        if readFailed { reload() }
    }

    private func reload() {
        do {
            saved = try read()
            readFailed = false
            feedback = nil
        } catch {
            readFailed = true
            feedback = "Couldn’t read the saved stream key. Unlock this iPhone and reopen YouTube settings."
        }
    }

    @discardableResult func save(key: String) -> Bool {
        let candidate: SavedYouTubeStreamKey
        do { candidate = try SavedYouTubeStreamKey(key: key) }
        catch {
            feedback = "Paste the stream key from YouTube Studio. Use the key field in Studio to copy it."
            return false
        }
        do {
            try write(candidate)
            saved = candidate
            feedback = "Stream key saved on this iPhone."
            readFailed = false
            return true
        } catch {
            feedback = "Couldn’t save the stream key. A previously saved key stays available. Try again."
            return false
        }
    }

    @discardableResult func remove() -> Bool {
        do {
            try write(nil)
            saved = nil
            feedback = "Stream key removed from this iPhone."
            readFailed = false
            return true
        } catch {
            feedback = "Couldn’t remove the stream key. Try again."
            return false
        }
    }
}

enum YouTubeStreamKeyStore {
    // The earlier payload's additional name field is ignored by JSONDecoder.
    struct Payload: Codable {
        let key: String
    }

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.smith3v.stream14.youtube",
         kSecAttrAccount as String: "studio-stream-key",
         kSecAttrSynchronizable as String: false]
    }

    static func read() throws -> SavedYouTubeStreamKey? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { throw StoreError.unavailable }
        return try SavedYouTubeStreamKey(key: payload.key)
    }

    static func write(_ value: SavedYouTubeStreamKey?) throws {
        guard let value else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw StoreError.unavailable }
            return
        }
        let data = try JSONEncoder().encode(Payload(key: value.destination.streamName))
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        // Update the single record in place so replacement failure preserves it.
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw StoreError.unavailable }
    }

    private enum StoreError: Error { case unavailable }
}
