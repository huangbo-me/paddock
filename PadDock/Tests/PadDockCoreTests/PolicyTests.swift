import XCTest
@testable import PadDockCore

final class PolicyTests: XCTestCase {
    let target = Pairing(name: "Test iPad", usbSerial: "usb-A", sidecarID: "sc-A")
    func observation(usb: [String] = ["usb-A"], available: Bool = true, connected: Bool = false, display: Bool = false, locked: Bool = false) -> Observation {
        Observation(usbSerials: usb, targetAvailable: available, connected: connected, displayOnline: display, locked: locked)
    }
    func testOnlyPairedUSBTriggersConnection() {
        var p = ConnectionPolicy(pairing: target)
        XCTAssertEqual(p.next(observation: observation(usb: ["usb-B"]), now: 0), .waitingForCable)
        XCTAssertEqual(p.next(observation: observation(), now: 1), .connect)
    }
    func testManualPauseSuppressesReconnectEvenAfterUSBReinsert() {
        var p = ConnectionPolicy(pairing: target); p.paused = true
        XCTAssertEqual(p.next(observation: observation(usb: []), now: 0), .paused)
        XCTAssertEqual(p.next(observation: observation(), now: 1), .paused)
    }
    func testLockedSessionNeverConnects() {
        var p = ConnectionPolicy(pairing: target)
        XCTAssertEqual(p.next(observation: observation(locked: true), now: 0), .waitingForUnlock)
    }
    func testCallbackSuccessNeedsOnlineDisplayAndStability() {
        var p = ConnectionPolicy(pairing: target)
        XCTAssertEqual(p.next(observation: observation(), now: 0), .connect)
        p.connectionFinished(success: true, now: 1)
        XCTAssertEqual(p.next(observation: observation(connected: true), now: 2), .verifying)
        XCTAssertEqual(p.next(observation: observation(connected: true, display: true), now: 3), .verifying)
        XCTAssertEqual(p.next(observation: observation(connected: true, display: true), now: 6), .connected)
    }
    func testVanishingSessionAfterSuccessBacksOff() {
        var p = ConnectionPolicy(pairing: target)
        _ = p.next(observation: observation(), now: 0)
        p.connectionFinished(success: true, now: 1)
        XCTAssertEqual(p.next(observation: observation(), now: 14), .retryLater)
        XCTAssertEqual(p.next(observation: observation(), now: 15), .retryLater)
        XCTAssertEqual(p.next(observation: observation(), now: 20), .connect)
    }
    func testFailureBackoffGrowsAndIsBounded() {
        var p = ConnectionPolicy(pairing: target)
        for i in 0..<10 { p.connectionFinished(success: false, now: Double(i)*1000) }
        XCTAssertEqual(p.retryAfter, 9060)
    }
    func testNoConcurrentConnectionsAndTimeoutRecovery() {
        var p = ConnectionPolicy(pairing: target)
        XCTAssertEqual(p.next(observation: observation(), now: 0), .connect)
        XCTAssertEqual(p.next(observation: observation(), now: 5), .connecting)
        XCTAssertEqual(p.next(observation: observation(), now: 31), .retryLater)
    }
    func testUSBRemovalResetsPendingVerification() {
        var p = ConnectionPolicy(pairing: target)
        _ = p.next(observation: observation(), now: 0)
        p.connectionFinished(success: true, now: 1)
        XCTAssertEqual(p.next(observation: observation(usb: []), now: 3), .waitingForCable)
        XCTAssertEqual(p.next(observation: observation(), now: 5), .connect)
    }
    func testUnavailableDeviceDoesNotConnect() {
        var p = ConnectionPolicy(pairing: target)
        XCTAssertEqual(p.next(observation: observation(available: false), now: 1), .waitingForDevice)
    }
    func testPairingRequiresUnambiguousWiredDevice() {
        XCTAssertFalse(PairingCandidate.valid(usbSerials: [], selectedID: "a", availableIDs: ["a"]))
        XCTAssertFalse(PairingCandidate.valid(usbSerials: ["a", "b"], selectedID: "a", availableIDs: ["a"]))
        XCTAssertFalse(PairingCandidate.valid(usbSerials: ["a"], selectedID: "wrong", availableIDs: ["a"]))
        XCTAssertTrue(PairingCandidate.valid(usbSerials: ["a"], selectedID: "a", availableIDs: ["a", "b"]))
    }
    func testNoBindingMeansNoAutomaticConnection() {
        var p = ConnectionPolicy(pairing: nil)
        XCTAssertEqual(p.next(observation: observation(), now: 0), .unpaired)
    }
    func testWirelessConnectionIsNeverReportedAsUSBSuccess() {
        var p = ConnectionPolicy(pairing: target)
        var o = observation(connected: true, display: true); o.usbTransport = false
        XCTAssertNotEqual(p.next(observation: o, now: 0), .connected)
        XCTAssertNotEqual(p.next(observation: o, now: 5), .connected)
    }
    func testPairingRequiresMatchingSingleUSBForWholeVerification() {
        XCTAssertFalse(PairingCandidate.canCommit(candidateSerial: "a", usbSerials: ["a", "b"], requestSucceeded: true, connectedUSBDisplay: true, stableSeconds: 4))
        XCTAssertFalse(PairingCandidate.canCommit(candidateSerial: "a", usbSerials: ["b"], requestSucceeded: true, connectedUSBDisplay: true, stableSeconds: 4))
        XCTAssertFalse(PairingCandidate.canCommit(candidateSerial: "a", usbSerials: ["a"], requestSucceeded: false, connectedUSBDisplay: true, stableSeconds: 4))
        XCTAssertTrue(PairingCandidate.canCommit(candidateSerial: "a", usbSerials: ["a"], requestSucceeded: true, connectedUSBDisplay: true, stableSeconds: 4))
    }
    func testNoConcurrentNativeRequestAndLateConnectHonorsDisconnect() {
        var gate = NativeOperationGate()
        let first = gate.begin(.connect)!
        XCTAssertNil(gate.begin(.connect))
        gate.requestDisconnect()
        XCTAssertNil(gate.begin(.disconnect))
        XCTAssertEqual(gate.finish(first, succeeded: true), .disconnect)
        let second = gate.begin(.disconnect)!
        XCTAssertEqual(gate.finish(first, succeeded: true), .none)
        XCTAssertTrue(gate.isBusy)
        XCTAssertEqual(gate.finish(second, succeeded: true), .none)
        XCTAssertFalse(gate.isBusy)
    }
    func testMigrationRequiresStableMirrorAndUSBSession() {
        XCTAssertFalse(MigrationSafety.verified(anchorOnline: true, mirrorMatches: false, usbPresent: true, usbDisplayOnline: true, stableSeconds: 5))
        XCTAssertFalse(MigrationSafety.verified(anchorOnline: true, mirrorMatches: true, usbPresent: true, usbDisplayOnline: false, stableSeconds: 5))
        XCTAssertFalse(MigrationSafety.verified(anchorOnline: true, mirrorMatches: true, usbPresent: true, usbDisplayOnline: true, stableSeconds: 2))
        XCTAssertTrue(MigrationSafety.verified(anchorOnline: true, mirrorMatches: true, usbPresent: true, usbDisplayOnline: true, stableSeconds: 5))
    }
    func testLoadedLegacyJobIsFoundWithoutPlist() {
        let output = "PID\tStatus\tLabel\n123\t0\tlocal.test.ipad-auto-sidecar\n-\t0\tlocal.test.ipad-headless-support\n1\t0\tcom.apple.example\n"
        XCTAssertEqual(LegacyJobParser.labels(output: output), ["local.test.ipad-auto-sidecar", "local.test.ipad-headless-support"])
    }
}
