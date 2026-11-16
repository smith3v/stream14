import Foundation
import Testing
@testable import Stream14

@MainActor struct YouTubeStreamKeySettingsTests {
    @Test func persistenceReplacementAndRemovalKeepExplicitMode() throws {
        var stored: SavedYouTubeStreamKey?
        var choice = YouTubeDestinationChoice.connectedEvent
        var rejectWrite = false
        func makeSettings() -> YouTubeStreamKeySettings {
            YouTubeStreamKeySettings(choice: choice, read: { stored }, write: {
                if rejectWrite { throw CocoaError(.fileWriteNoPermission) }
                stored = $0
            }, persistChoice: { choice = $0 })
        }

        let first = makeSettings()
        #expect(first.save(name: "  Court A  ", key: "  fake-initial-key\n"))
        #expect(first.choice == .connectedEvent)
        first.select(.streamKey)

        let relaunched = makeSettings()
        #expect(relaunched.saved?.name == "Court A")
        #expect(relaunched.saved?.destination.streamName == "fake-initial-key")
        #expect(relaunched.saved?.destination.endpoint.absoluteString == "rtmps://a.rtmps.youtube.com:443/live2")
        #expect(relaunched.choice == .streamKey)

        rejectWrite = true
        #expect(!relaunched.save(name: "Court B", key: "fake-replacement-key"))
        #expect(relaunched.saved?.name == "Court A")
        #expect(makeSettings().saved?.name == "Court A")
        #expect(!relaunched.remove())
        #expect(relaunched.saved?.name == "Court A")
        rejectWrite = false

        relaunched.select(.connectedEvent)
        #expect(relaunched.save(name: "", key: "fake-replacement-key"))
        #expect(makeSettings().saved?.name == "YouTube stream key")
        #expect(makeSettings().choice == .connectedEvent)
        relaunched.select(.streamKey)
        #expect(relaunched.remove())
        #expect(makeSettings().choice == .streamKey)
        #expect(makeSettings().saved == nil)
    }

    @Test func validationAndReflectionDoNotExposeKey() throws {
        let settings = YouTubeStreamKeySettings()
        #expect(!settings.save(name: "Court", key: "rtmps://a.rtmps.youtube.com/live2/fake-key"))
        #expect(!settings.save(name: "Court", key: "fake key"))
        let saved = try SavedYouTubeStreamKey(name: "Copied fake-key-secret", key: "fake-key-secret")
        #expect(saved.name == "YouTube stream key")
        #expect(!String(reflecting: saved).contains("fake-key-secret"))
        let intent = StreamKeyIntent(key: saved, profile: .hd, overlayURL: "https://example.net/private-token")
        #expect(!String(reflecting: intent).contains("fake-key-secret"))
        #expect(!String(reflecting: intent).contains("private-token"))
    }
}
