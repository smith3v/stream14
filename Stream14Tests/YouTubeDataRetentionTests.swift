import Foundation
import Testing
@testable import Stream14

@MainActor struct YouTubeDataRetentionTests {
    private let origin = Date(timeIntervalSince1970: 1_800_000_000)
    private let limit: TimeInterval = 30 * 24 * 60 * 60

    @Test func bindingAndRemoteExpireAtThirtyDaysAndUpdatesNeverRenewAge() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var clock = origin
        let binding = PendingBroadcastIntentStore(directory: directory.appendingPathComponent("binding"), now: { clock })
        let remote = PendingRemoteBroadcastStore(url: directory.appendingPathComponent("remote.json"), now: { clock })
        var intent = PendingBroadcastIntent(channelID: "invented-channel", broadcastID: "invented-event", profile: .hd)
        intent.verifiedAt = origin
        var pending = PendingRemoteBroadcast(channelID: "invented-channel", eventID: "invented-event")
        pending.verifiedAt = origin
        try binding.save(intent); try remote.save(pending)
        clock = origin.addingTimeInterval(limit - 1)
        intent.phase = .prepared; intent.verifiedAt = clock
        pending.interrupted = true; pending.verifiedAt = clock
        try binding.save(intent); try remote.save(pending)
        #expect(try binding.load()?.verifiedAt == origin)
        #expect(try remote.load()?.verifiedAt == origin)
        clock = origin.addingTimeInterval(limit)
        #expect(try binding.expireIfNeeded())
        #expect(try remote.expireIfNeeded())
        #expect(binding.requiresStudioResolution && remote.requiresStudioResolution)
        #expect(!binding.hasSavedAPIData && !remote.hasSavedAPIData)
        #expect(throws: YouTubeBindingError.studioResolutionRequired) { try binding.save(intent) }
        #expect(throws: YouTubeBindingError.studioResolutionRequired) { try remote.save(pending) }
    }

    @Test func legacyUndatedAndFutureDatedIdentifiersConvertToNonidentifyingGuards() throws {
        for timestamp in [nil, origin.addingTimeInterval(1)] as [Date?] {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var intent = PendingBroadcastIntent(channelID: "invented-channel", broadcastID: "invented-event", profile: .hd)
            intent.verifiedAt = timestamp
            var pending = PendingRemoteBroadcast(channelID: "invented-channel", eventID: "invented-event")
            pending.verifiedAt = timestamp
            try JSONEncoder().encode([intent]).write(to: directory.appendingPathComponent("binding-intent.json"))
            try JSONEncoder().encode(pending).write(to: directory.appendingPathComponent("remote.json"))
            let binding = PendingBroadcastIntentStore(directory: directory, now: { origin })
            let remote = PendingRemoteBroadcastStore(url: directory.appendingPathComponent("remote.json"), now: { origin })
            #expect(try binding.expireIfNeeded())
            #expect(try remote.expireIfNeeded())
            for name in ["studio-resolution-required", "youtube-studio-resolution-required"] {
                let marker = try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
                #expect(marker == "Studio resolution required")
            }
        }
    }

    @Test func partialExpiryFailureRetainsGuardRejectsLateWritesAndCanBeRetried() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var clock = origin
        let url = directory.appendingPathComponent("remote.json")
        var failRemoval = false
        let remote = PendingRemoteBroadcastStore(url: url, now: { clock }, remove: {
            if failRemoval && $0 == url { throw CocoaError(.fileWriteNoPermission) }
            try FileManager.default.removeItem(at: $0)
        })
        var pending = PendingRemoteBroadcast(channelID: "invented-channel", eventID: "invented-event")
        pending.verifiedAt = origin
        try remote.save(pending)
        clock = origin.addingTimeInterval(limit)
        failRemoval = true
        #expect(throws: CocoaError.self) { try remote.expireIfNeeded() }
        #expect(remote.requiresStudioResolution && remote.hasSavedAPIData)
        #expect(throws: YouTubeBindingError.studioResolutionRequired) { try remote.save(pending) }
        let relaunched = PendingRemoteBroadcastStore(url: url, now: { clock })
        try relaunched.eraseAPIData()
        #expect(relaunched.requiresStudioResolution && !relaunched.hasSavedAPIData)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("retention-fixture-" + UUID().uuidString)
    }
}
