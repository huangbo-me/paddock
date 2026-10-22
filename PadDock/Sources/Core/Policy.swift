import Foundation

public struct Pairing: Codable, Equatable {
    public var name: String
    public var usbSerial: String
    public var sidecarID: String
    public init(name: String, usbSerial: String, sidecarID: String) {
        self.name = name; self.usbSerial = usbSerial; self.sidecarID = sidecarID
    }
}

public struct Observation {
    public var usbSerials: [String]
    public var targetAvailable: Bool
    public var connected: Bool
    public var displayOnline: Bool
    public var locked: Bool
    public var usbTransport = true
    public init(usbSerials: [String], targetAvailable: Bool, connected: Bool, displayOnline: Bool, locked: Bool) {
        self.usbSerials = usbSerials; self.targetAvailable = targetAvailable
        self.connected = connected; self.displayOnline = displayOnline; self.locked = locked
    }
}

public enum ConnectionAction: String, Equatable {
    case unpaired, paused, waitingForCable, waitingForUnlock, waitingForDevice
    case connect, connecting, verifying, connected, retryLater
}

public enum PairingCandidate {
    public static func canCommit(candidateSerial: String, usbSerials: [String], requestSucceeded: Bool, connectedUSBDisplay: Bool, stableSeconds: Double) -> Bool {
        !candidateSerial.isEmpty && Set(usbSerials) == [candidateSerial] && requestSucceeded && connectedUSBDisplay && stableSeconds >= 3
    }
    public static func valid(usbSerials: [String], selectedID: String, availableIDs: [String]) -> Bool {
        Set(usbSerials).count == 1 && !usbSerials.contains("") && !selectedID.isEmpty && availableIDs.contains(selectedID)
    }
}

public struct ConnectionPolicy {
    public var pairing: Pairing?
    public var paused = false
    public private(set) var retryAfter: Double = 0
    private var startedAt: Double?
    private var verificationDeadline: Double?
    private var stableSince: Double?
    private var failures = 0

    public init(pairing: Pairing?) { self.pairing = pairing }
    public mutating func reset() {
        startedAt = nil; verificationDeadline = nil; stableSince = nil
        failures = 0; retryAfter = 0
    }
    public mutating func connectionFinished(success: Bool, now: Double) {
        startedAt = nil; stableSince = nil
        if success { verificationDeadline = now + 12 }
        else {
            verificationDeadline = nil
            failures = min(failures + 1, 5)
            retryAfter = now + min(60, 5 * pow(2, Double(failures - 1)))
        }
    }
    public mutating func next(observation o: Observation, now: Double) -> ConnectionAction {
        guard let pairing else { return .unpaired }
        if paused { return .paused }
        guard o.usbSerials.contains(pairing.usbSerial) else { reset(); return .waitingForCable }
        if o.locked { return .waitingForUnlock }
        if o.connected && o.displayOnline && o.usbTransport {
            if stableSince == nil { stableSince = now }
            if now - (stableSince ?? now) >= 3 {
                startedAt = nil; verificationDeadline = nil; failures = 0; retryAfter = 0
                return .connected
            }
            return .verifying
        }
        stableSince = nil
        if let deadline = verificationDeadline {
            if now < deadline { return .verifying }
            connectionFinished(success: false, now: now)
            return .retryLater
        }
        if let startedAt {
            if now - startedAt < 30 { return .connecting }
            connectionFinished(success: false, now: now)
            return .retryLater
        }
        if now < retryAfter { return .retryLater }
        if !o.targetAvailable { return .waitingForDevice }
        startedAt = now
        return .connect
    }
}

public struct NativeOperationGate {
    public enum Kind { case connect, disconnect }
    public enum Followup { case none, disconnect }
    private var sequence = 0
    private var active: (Int, Kind)?
    private var disconnectWanted = false
    public var isBusy: Bool { active != nil }
    public init() {}
    public mutating func begin(_ kind: Kind) -> Int? {
        guard active == nil else { return nil }
        sequence += 1; active = (sequence, kind); return sequence
    }
    public mutating func requestDisconnect() { disconnectWanted = true }
    public mutating func finish(_ token: Int, succeeded: Bool) -> Followup {
        guard let operation = active, operation.0 == token else { return .none }
        active = nil
        let followup = operation.1 == .connect && disconnectWanted
        disconnectWanted = false
        // Even an error callback can leave a partial native session to reconcile.
        return followup ? .disconnect : .none
    }
}

public enum MigrationSafety {
    public static func verified(anchorOnline: Bool, mirrorMatches: Bool, usbPresent: Bool, usbDisplayOnline: Bool, stableSeconds: Double) -> Bool {
        anchorOnline && mirrorMatches && usbPresent && usbDisplayOnline && stableSeconds >= 3
    }
}

public enum LegacyJobParser {
    public static func labels(output: String) -> [String] {
        output.split(separator: "\n").compactMap { line in
            let fields = line.split(whereSeparator: { $0.isWhitespace })
            guard fields.count == 3, let label = fields.last,
                  label.hasSuffix(".ipad-auto-sidecar") || label.hasSuffix(".ipad-headless-support") else { return nil }
            return String(label)
        }
    }
}
