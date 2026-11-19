import Foundation
import Testing
@testable import Stream14

@MainActor struct YouTubeStreamKeySettingsTests {
    @Test func keyPersistsAcrossReplacementAndConfirmedRemoval() throws {
        var stored: SavedYouTubeStreamKey?
        var rejectWrite = false
        func makeSettings() -> YouTubeStreamKeySettings {
            YouTubeStreamKeySettings(read: { stored }, write: {
                if rejectWrite { throw CocoaError(.fileWriteNoPermission) }
                stored = $0
            })
        }

        let first = makeSettings()
        #expect(first.save(key: "  fake-initial-key\n"))
        #expect(first.setRecoveryProfile(.hd))
        let relaunched = makeSettings()
        #expect(relaunched.saved?.destination.streamName == "fake-initial-key")
        #expect(relaunched.saved?.destination.endpoint.absoluteString == "rtmps://a.rtmps.youtube.com:443/live2")
        #expect(relaunched.saved?.recoveryProfile == .hd)

        rejectWrite = true
        #expect(!relaunched.save(key: "fake-replacement-key"))
        #expect(relaunched.saved?.destination.streamName == "fake-initial-key")
        #expect(makeSettings().saved?.destination.streamName == "fake-initial-key")
        #expect(!relaunched.remove())
        #expect(relaunched.saved != nil)
        rejectWrite = false

        #expect(relaunched.save(key: "fake-replacement-key"))
        #expect(makeSettings().saved?.destination.streamName == "fake-replacement-key")
        #expect(makeSettings().saved?.recoveryProfile == nil)
        #expect(relaunched.remove())
        #expect(makeSettings().saved == nil)
    }

    @Test func earlierNamedKeyCanStillBeRead() throws {
        let legacy = Data(#"{"name":"Legacy name","key":"fake-legacy-key"}"#.utf8)
        let payload = try JSONDecoder().decode(YouTubeStreamKeyStore.Payload.self, from: legacy)
        #expect(try SavedYouTubeStreamKey(key: payload.key).destination.streamName == "fake-legacy-key")
        #expect(payload.recoveryProfile == nil)
        let encoded = try JSONEncoder().encode(payload)
        #expect(!String(decoding: encoded, as: UTF8.self).contains("Legacy name"))
    }

    @Test func clearingAnUnreadKeyDoesNotCountAsDisarmed() {
        let settings = YouTubeStreamKeySettings(read: { throw CocoaError(.fileReadNoPermission) })
        #expect(!settings.setRecoveryProfile(nil))
    }

    @Test func validationAndReflectionDoNotExposeKey() throws {
        let settings = YouTubeStreamKeySettings()
        #expect(!settings.save(key: "rtmps://a.rtmps.youtube.com/live2/fake-key"))
        #expect(!settings.save(key: "fake key"))
        let saved = try SavedYouTubeStreamKey(key: "fake-key-secret")
        #expect(!String(reflecting: saved).contains("fake-key-secret"))
        let intent = StreamKeyIntent(key: saved, profile: .hd, overlayURL: "https://example.net/private-token")
        #expect(!String(reflecting: intent).contains("fake-key-secret"))
        #expect(!String(reflecting: intent).contains("private-token"))
    }
}
