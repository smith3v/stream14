import Foundation
import Testing
@testable import Stream14

struct RTMPSUploadAffinityTests {
    @Test func readinessBypassRequiresExactlyTheAdmittedContext() throws {
        let original = try prepared()
        var affinity = RTMPSUploadAffinity()
        #expect(!affinity.hasAdmittedTransport)
        let admittedOriginal = affinity.admit(original)
        #expect(admittedOriginal)
        #expect(affinity.hasAdmittedTransport)
        #expect(affinity.permits(original))
        let changed = try [
            prepared(channel: "other-channel"), prepared(event: "other-event"),
            prepared(stream: "other-stream"), prepared(profile: .fullHD),
            prepared(generation: 2), prepared(endpoint: "rtmps://rtmps.youtube.com:443/other-path")
        ]
        for candidate in changed {
            #expect(!affinity.permits(candidate))
            let admittedChanged = affinity.admit(candidate)
            #expect(!admittedChanged)
            #expect(affinity.permits(original))
        }
    }
    @Test func fileOnlyRestartKeepsAffinityAndNewSessionCanResetIt() throws {
        let original = try prepared()
        let other = try prepared(event: "other-event")
        var affinity = RTMPSUploadAffinity()
        let admittedOriginal = affinity.admit(original)
        #expect(admittedOriginal)
        affinity.beginRecordingSession(keepingTransportEpoch: true)
        #expect(!affinity.permits(other))
        affinity.beginRecordingSession(keepingTransportEpoch: false)
        #expect(!affinity.hasAdmittedTransport)
        let admittedOther = affinity.admit(other)
        #expect(admittedOther)
        affinity.endCaptureSession()
        #expect(!affinity.hasAdmittedTransport)
        let admittedAfterReset = affinity.admit(original)
        #expect(admittedAfterReset)
    }
    @Test func diagnosticReflectionOmitsContextAndCredentials() throws {
        let context = try #require(RTMPSUploadContext(prepared()))
        #expect(context.description == "RTMPS upload context (redacted)")
        #expect(context.debugDescription == context.description)
        #expect(context.customMirror.children.count == 1)
        #expect(context.customMirror.children.first?.value as? String == "<redacted>")
    }

    private func prepared(channel: String = "fixture-channel", event: String = "fixture-event",
        stream: String = "fixture-stream", profile: SessionProfile = .hd,
        generation: UInt64 = 1, endpoint: String = "rtmps://rtmps.youtube.com:443/live2") throws -> PreparedYouTubeIngestion {
        PreparedYouTubeIngestion(broadcast: YouTubeBroadcast(id: event,
            snippet: .init(channelId: channel, title: nil, scheduledStartTime: nil, isDefaultBroadcast: false),
            status: nil, contentDetails: nil), streamID: stream, profile: profile, generation: generation,
            destination: try YouTubeIngestionDestination(address: endpoint, streamName: "fixture-not-a-key"))
    }
}
