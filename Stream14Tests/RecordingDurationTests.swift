import Foundation
import Testing
@testable import Stream14

struct RecordingDurationTests {
    @Test(arguments: [
        (0.0, "00:00:00", "0 seconds"),
        (21.9, "00:00:21", "21 seconds"),
        (71.2, "00:01:11", "1 minute, 11 seconds"),
        (3599.9, "00:59:59", "59 minutes, 59 seconds"),
        (3600.0, "01:00:00", "1 hour"),
        (3636.3, "01:00:36", "1 hour, 36 seconds"),
        (360000.0, "100:00:00", "100 hours")
    ])
    func formatsWholeElapsedSeconds(seconds: Double, clock: String, spoken: String) throws {
        let duration = try #require(RecordingDuration(seconds))
        let locale = Locale(identifier: "en_US")
        #expect(duration.clock(locale: locale) == clock)
        #expect(duration.spoken(locale: locale) == spoken)
    }

    @Test(arguments: [nil, -1.0, .nan, .infinity, .greatestFiniteMagnitude] as [Double?])
    func omitsUnavailableDurations(seconds: Double?) {
        #expect(RecordingDuration(seconds) == nil)
    }
}
