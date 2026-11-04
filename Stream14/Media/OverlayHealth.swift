import Foundation

/// Times are monotonic seconds supplied by the renderer (or a deterministic test).
struct OverlayHealth {
    private(set) var sourceTime: TimeInterval?
    private(set) var renderTime: TimeInterval?
    private(set) var recovered = false
    var manuallyHidden = false

    mutating func sourceSucceeded(at time: TimeInterval) { sourceTime = time }

    mutating func rendered(at time: TimeInterval, freshDocument: Bool) {
        renderTime = time
        if freshDocument, let sourceTime, time - sourceTime < 10 { recovered = true }
    }

    mutating func expire(at time: TimeInterval) {
        if !isHealthy(at: time) { recovered = false }
    }

    func isHealthy(at time: TimeInterval) -> Bool {
        guard let sourceTime, let renderTime else { return false }
        return time - sourceTime < 10 && time - renderTime < 10
    }

    func isVisible(at time: TimeInterval) -> Bool {
        recovered && isHealthy(at: time) && !manuallyHidden
    }
}
