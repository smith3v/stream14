import Testing
@testable import Stream14

@MainActor
struct OverlayHealthTests {
    @Test func deadlineAndCachedSnapshots() {
        var health = OverlayHealth()
        health.sourceSucceeded(at: 0)
        health.rendered(at: 0, freshDocument: true)
        #expect(health.isVisible(at: 9.999))
        health.rendered(at: 9, freshDocument: false)
        #expect(!health.isVisible(at: 10))
        #expect(!health.isVisible(at: 11))
        health.expire(at: 10)
        health.sourceSucceeded(at: 11)
        #expect(!health.isVisible(at: 11))
        health.rendered(at: 11.1, freshDocument: true)
        #expect(health.isVisible(at: 11.1))
    }

    @Test func renderingHasIndependentDeadline() {
        var health = OverlayHealth()
        health.sourceSucceeded(at: 0)
        health.rendered(at: 0, freshDocument: true)
        health.sourceSucceeded(at: 9)
        #expect(!health.isVisible(at: 10))
    }

    @Test func briefFailureUnchangedHealthySourceAndManualPrecedence() {
        var health = OverlayHealth()
        health.sourceSucceeded(at: 0)
        health.rendered(at: 0, freshDocument: true)
        // A failed reload changes neither successful timestamp.
        #expect(health.isVisible(at: 4))
        // Pixel equality is irrelevant: confirmed access + a new render is healthy.
        health.sourceSucceeded(at: 8)
        health.rendered(at: 8.1, freshDocument: true)
        #expect(health.isVisible(at: 12))
        health.manuallyHidden = true
        health.expire(at: 20)
        health.sourceSucceeded(at: 21)
        health.rendered(at: 21.1, freshDocument: true)
        #expect(health.isHealthy(at: 21.1))
        #expect(!health.isVisible(at: 21.1))
        health.manuallyHidden = false
        #expect(health.isVisible(at: 21.1))
    }
}
