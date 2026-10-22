import XCTest
import CryptoKit
@testable import PadDockCore
final class MemoryCommerceStorage: CommerceStorage {
    var data: Data?
    var failRead = false, failWrite = false
    func read() throws -> Data? { if failRead { throw CocoaError(.fileReadNoPermission) }; return data }
    func write(_ data: Data) throws { if failWrite { throw CocoaError(.fileWriteNoPermission) }; self.data = data }
}
final class CommerceTests: XCTestCase {
    let key = Curve25519.Signing.PrivateKey()
    func code(product: String = "paddock", major: Int = 1, issued: Int64 = 1000, schema: Int = 1) throws -> String {
        let payload = Data("{\"schema\":\(schema),\"product\":\"\(product)\",\"majorVersion\":\(major),\"licenseID\":\"unit-license-001\",\"issuedAt\":\(issued)}".utf8)
        return "PD1." + payload.base64EncodedString() + "." + (try key.signature(for: payload)).base64EncodedString()
    }
    func verifier() throws -> LicenseVerifier { try LicenseVerifier(publicKey: key.publicKey.rawRepresentation, commercialMajor: 1) }
    func testValidOfflineLicenseAndWhitespace() throws {
        XCTAssertEqual(try verifier().verify(" \n" + code() + "\n", now: 2000).licenseID, "unit-license-001")
    }
    func testTamperedLicenseRejected() throws {
        let original = try code().split(separator: ".").map(String.init)
        let altered = Data("{\"schema\":1,\"product\":\"paddock\",\"majorVersion\":1,\"licenseID\":\"forged\",\"issuedAt\":1000}".utf8)
        XCTAssertThrowsError(try verifier().verify("PD1." + altered.base64EncodedString() + "." + original[2], now: 2000))
    }
    func testForeignProductVersionAndFutureDateRejected() throws {
        for bad in [try code(product: "other"), try code(major: 2), try code(schema: 2), try code(issued: 9000), try code(issued: -1)] { XCTAssertThrowsError(try verifier().verify(bad, now: 2000)) }
    }
    func testDifferentSigningKeyRejected() throws {
        let v = try LicenseVerifier(publicKey: Curve25519.Signing.PrivateKey().publicKey.rawRepresentation, commercialMajor: 1)
        XCTAssertThrowsError(try v.verify(code(), now: 2000))
    }
    func testMalformedOrHugeLicenseRejected() throws {
        for value in ["", "PD1.a.b", "PD1...", String(repeating: "a", count: 9000)] { XCTAssertThrowsError(try verifier().verify(value, now: 2000)) }
    }
    func testTrialBoundaryIsFourteenDays() {
        let trial = TrialRecord(startedAt: 1000, lastSeenAt: 1000)
        XCTAssertEqual(trial.status(now: 1000), .trial(daysRemaining: 14))
        XCTAssertEqual(trial.status(now: 1000 + 14*86400 - 1), .trial(daysRemaining: 1))
        XCTAssertEqual(trial.status(now: 1000 + 14*86400), .expired)
    }
    func testClockRollbackCannotRenewTrial() {
        let trial = TrialRecord(startedAt: 1000, lastSeenAt: 2000)
        XCTAssertEqual(trial.status(now: 1500), .clockChanged)
        XCTAssertEqual(trial.status(now: 1900), .trial(daysRemaining: 14))
    }
    func testMissingPurchaseLinkAndForeignDomainsDisabled() {
        for value in ["", "https://afdian.com", "http://afdian.com/a/paddock", "https://afdian.com.evil.test/a/x", "https://evil.test/?afdian.com", "https://u:p@afdian.com/a/x", "https://afdian.com:8443/a/x"] { XCTAssertNil(PurchaseLink.validated(value)) }
        XCTAssertEqual(PurchaseLink.validated("https://afdian.com/a/example")?.host, "afdian.com")
    }
    func testExpiredTrialBlocksAutomationWithExternalScreen() {
        XCTAssertFalse(CommerceAccess.allowsAutomaticConnection(entitled: false, paired: true, headless: true, independentDisplay: true))
        XCTAssertFalse(CommerceAccess.allowsAutomaticConnection(entitled: false, paired: true, headless: false, independentDisplay: false))
    }
    func testExpiredHeadlessRecoveryRemainsAvailable() {
        XCTAssertTrue(CommerceAccess.allowsAutomaticConnection(entitled: false, paired: true, headless: true, independentDisplay: false))
        XCTAssertFalse(CommerceAccess.allowsAutomaticConnection(entitled: false, paired: false, headless: true, independentDisplay: false))
    }
    func testUnknownOrVirtualDisplaysDoNotRemoveRecovery() {
        for builtIn in [false, true] {
            XCTAssertFalse(CommerceAccess.isIndependentUsableScreen(builtIn: builtIn, anchor: true, sidecar: false, classificationKnown: true))
            XCTAssertFalse(CommerceAccess.isIndependentUsableScreen(builtIn: builtIn, anchor: false, sidecar: true, classificationKnown: true))
            XCTAssertFalse(CommerceAccess.isIndependentUsableScreen(builtIn: builtIn, anchor: false, sidecar: false, classificationKnown: false))
        }
        let unknown = CommerceAccess.isIndependentUsableScreen(builtIn: false, anchor: false, sidecar: false, classificationKnown: true)
        XCTAssertFalse(unknown)
        XCTAssertTrue(CommerceAccess.allowsAutomaticConnection(entitled: false, paired: true, headless: true, independentDisplay: unknown))
        XCTAssertTrue(CommerceAccess.isIndependentUsableScreen(builtIn: true, anchor: false, sidecar: false, classificationKnown: true))
    }
    func testEntitledUserCanAutomaticallyConnect() {
        XCTAssertTrue(CommerceAccess.allowsAutomaticConnection(entitled: true, paired: false, headless: false, independentDisplay: true))
    }
    func testTrialPersistsAcrossNewEngineAndCannotRestart() throws {
        let store = MemoryCommerceStorage(), first = CommerceEngine(storage: MemoryCommerceStorage(), verifier: try verifier())
        XCTAssertEqual(first.status(now: 1000), .notStarted)
        let engine = CommerceEngine(storage: store, verifier: try verifier()); try engine.startTrial(now: 1000)
        let second = CommerceEngine(storage: store, verifier: try verifier())
        XCTAssertEqual(second.status(now: 1000 + 14*86400), .expired)
        XCTAssertThrowsError(try second.startTrial(now: 1000 + 14*86400))
    }
    func testUnreadableAndMalformedStorageNeverStartFreshTrial() throws {
        let store = MemoryCommerceStorage(); store.failRead = true
        let engine = CommerceEngine(storage: store, verifier: try verifier())
        XCTAssertEqual(engine.status(now: 1000), .unavailable); XCTAssertThrowsError(try engine.startTrial(now: 1000))
        store.failRead = false; store.data = Data("corrupt".utf8)
        XCTAssertEqual(CommerceEngine(storage: store, verifier: try verifier()).status(now: 1000), .unavailable)
    }
    func testFailedSaveDoesNotUnlockTrialOrLicense() throws {
        let store = MemoryCommerceStorage(); store.failWrite = true
        let engine = CommerceEngine(storage: store, verifier: try verifier())
        XCTAssertThrowsError(try engine.startTrial(now: 2000)); XCTAssertEqual(engine.status(now: 2000), .notStarted)
        XCTAssertThrowsError(try engine.activate(code(), now: 2000)); XCTAssertEqual(engine.status(now: 2000), .notStarted)
    }
    func testInvalidCodeDoesNotOverwritePaidLicense() throws {
        let store = MemoryCommerceStorage(), v = try verifier()
        let engine = CommerceEngine(storage: store, verifier: v); try engine.activate(code(), now: 2000)
        let before = store.data
        XCTAssertThrowsError(try engine.activate("bad", now: 2000)); XCTAssertEqual(store.data, before)
        XCTAssertEqual(engine.status(now: 2000), .licensed(id: "unit-license-001"))
    }
    func testPaidLicenseWorksAfterExpiryAndClockRollback() throws {
        let engine = CommerceEngine(storage: MemoryCommerceStorage(), verifier: try verifier())
        try engine.startTrial(now: 2000); try engine.activate(code(), now: 3000)
        XCTAssertEqual(engine.status(now: 1000), .licensed(id: "unit-license-001"))
        XCTAssertEqual(engine.status(now: 2000000), .licensed(id: "unit-license-001"))
    }
    func testCheckpointPersistsClockHighWaterMark() throws {
        let store = MemoryCommerceStorage(); let engine = CommerceEngine(storage: store, verifier: try verifier())
        try engine.startTrial(now: 1000); try engine.checkpoint(now: 10000)
        XCTAssertEqual(CommerceEngine(storage: store, verifier: try verifier()).status(now: 2000), .clockChanged)
    }
}
