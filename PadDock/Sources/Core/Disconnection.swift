import Foundation

/// A successful native callback is only an acknowledgement, not proof that the screen is gone.
public struct DisconnectionPolicy {
    public enum Step { case wait, send, completed, failed }
    private var deadline: Double = 0
    private var stableSince: Double?
    private var retryAt: Double = 0
    private var attempts = 0
    public init() {}
    public mutating func start(now: Double) {
        deadline = now + 20; stableSince = nil; retryAt = now; attempts = 0
    }
    public mutating func requestFinished(now: Double) { retryAt = now + 3 }
    public mutating func next(now: Double, observable: Bool, connected: Bool, displayOnline: Bool, requestBusy: Bool) -> Step {
        if observable && !connected && !displayOnline && !requestBusy {
            if stableSince == nil { stableSince = now }
            if now - (stableSince ?? now) >= 2 { return .completed }
        } else { stableSince = nil }
        if now >= deadline { return .failed }
        guard observable, !requestBusy, connected || displayOnline, now >= retryAt else { return .wait }
        guard attempts < 3 else { return .failed }
        attempts += 1
        return .send
    }
}
