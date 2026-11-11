import Testing
@testable import Stream14

@MainActor struct SessionWorkspaceTests {
    @Test func preparingNextClearsTransientFailureWithoutChangingArchive() {
        let models = InterfaceFixture.make("backup-failed")
        let media = models.media
        let originals = media.savedSamples.map(\.id)
        #expect(media.localSavingStatus.contains("Failed"))
        // The coordinator separately prevents the live session from being reset.
        #expect(!models.broadcast.prepareNextSession())
        // Simulate a settled local preview after the remote session was ended.
        media.installInterfaceFixture("ended")
        #expect(media.prepareNextSession())
        #expect(media.localSavingStatus == "Not started")
        #expect(media.uploadMessage == "Upload not started" && media.backupWarning.isEmpty)
        #expect(media.sampleURL == nil)
        #expect(media.savedSamples.map(\.id) == originals)
    }

    @Test func finalizationAndRecordingBlockNextSession() {
        for state in ["finalizing", "reconnecting", "upload-recovered"] {
            let models = InterfaceFixture.make(state)
            #expect(!models.media.prepareNextSession())
            #expect(!models.broadcast.prepareNextSession())
        }
    }
}
