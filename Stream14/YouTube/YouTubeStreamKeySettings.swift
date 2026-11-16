import Foundation
import Observation
import Security

enum YouTubeDestinationChoice: String, CaseIterable {
    case connectedEvent
    case streamKey

    var title: String {
        switch self {
        case .connectedEvent: "Connected YouTube event"
        case .streamKey: "Use a stream key"
        }
    }
}

/// Keep credentials out of reflection and encoders other than the Keychain store.
nonisolated struct SavedYouTubeStreamKey: Sendable, CustomReflectable {
    let name: String
    let destination: YouTubeIngestionDestination
    var customMirror: Mirror { Mirror(self, children: ["credentials": "<redacted>"]) }

    init(name: String, key: String) throws {
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let streamName = key.trimmingCharacters(in: .whitespacesAndNewlines)
        // Accept a key pasted from Studio, with no URL or path components.
        guard !streamName.isEmpty, streamName.utf8.allSatisfy({
            (48...57).contains($0) || (65...90).contains($0) ||
            (97...122).contains($0) || $0 == 45 || $0 == 95
        }) else { throw YouTubeBindingError.invalidDestination }
        self.name = displayName.isEmpty || displayName.contains(streamName) ? "YouTube stream key" : displayName
        destination = try YouTubeIngestionDestination(
            address: "rtmps://a.rtmps.youtube.com:443/live2", streamName: streamName)
    }
}

@MainActor @Observable final class YouTubeStreamKeySettings {
    private(set) var choice: YouTubeDestinationChoice
    private(set) var saved: SavedYouTubeStreamKey?
    private(set) var feedback: String?
    private var readFailed = false
    private let read: () throws -> SavedYouTubeStreamKey?
    private let write: (SavedYouTubeStreamKey?) throws -> Void
    private let persistChoice: (YouTubeDestinationChoice) -> Void

    init(choice: YouTubeDestinationChoice = .connectedEvent,
         read: @escaping () throws -> SavedYouTubeStreamKey? = { nil },
         write: @escaping (SavedYouTubeStreamKey?) throws -> Void = { _ in },
         persistChoice: @escaping (YouTubeDestinationChoice) -> Void = { _ in }) {
        self.choice = choice
        self.read = read
        self.write = write
        self.persistChoice = persistChoice
        reload()
    }

    static func deviceSettings(defaults: UserDefaults = .standard) -> YouTubeStreamKeySettings {
        let choiceKey = "YouTubeDestinationChoice"
        let choice = defaults.string(forKey: choiceKey).flatMap(YouTubeDestinationChoice.init(rawValue:))
        return YouTubeStreamKeySettings(choice: choice ?? .connectedEvent,
            read: YouTubeStreamKeyStore.read, write: YouTubeStreamKeyStore.write,
            persistChoice: { defaults.set($0.rawValue, forKey: choiceKey) })
    }

    func select(_ choice: YouTubeDestinationChoice) {
        self.choice = choice
        persistChoice(choice)
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

    @discardableResult func save(name: String, key: String) -> Bool {
        let candidate: SavedYouTubeStreamKey
        do { candidate = try SavedYouTubeStreamKey(name: name, key: key) }
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
    private struct Payload: Codable {
        let name: String
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
        return try SavedYouTubeStreamKey(name: payload.name, key: payload.key)
    }

    static func write(_ value: SavedYouTubeStreamKey?) throws {
        guard let value else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw StoreError.unavailable }
            return
        }
        let data = try JSONEncoder().encode(Payload(name: value.name, key: value.destination.streamName))
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
