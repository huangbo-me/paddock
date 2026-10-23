import XCTest
@testable import PadDockCore

final class DisconnectionTests: XCTestCase {
    func testSuccessCallbackDoesNotProveDisconnection() {
        var p = DisconnectionPolicy(); p.start(now: 0)
        XCTAssertEqual(p.next(now: 0, observable: true, connected: true, displayOnline: true, requestBusy: false), .send)
        p.requestFinished(now: 1)
        XCTAssertEqual(p.next(now: 2, observable: true, connected: true, displayOnline: true, requestBusy: false), .wait)
        XCTAssertEqual(p.next(now: 4, observable: true, connected: true, displayOnline: true, requestBusy: false), .send)
    }
    func testRequiresStableAbsenceOfBothConnectionAndDisplay() {
        var p = DisconnectionPolicy(); p.start(now: 0)
        XCTAssertEqual(p.next(now: 0, observable: true, connected: false, displayOnline: true, requestBusy: false), .send)
        p.requestFinished(now: 1)
        XCTAssertEqual(p.next(now: 2, observable: true, connected: false, displayOnline: false, requestBusy: false), .wait)
        XCTAssertEqual(p.next(now: 3, observable: true, connected: true, displayOnline: false, requestBusy: false), .wait)
        XCTAssertEqual(p.next(now: 4, observable: true, connected: false, displayOnline: false, requestBusy: false), .wait)
        XCTAssertEqual(p.next(now: 6, observable: true, connected: false, displayOnline: false, requestBusy: false), .completed)
    }
    func testMissingCallbackNeverStartsAnOverlappingRequestAndTimesOut() {
        var p = DisconnectionPolicy(); p.start(now: 0)
        XCTAssertEqual(p.next(now: 0, observable: true, connected: true, displayOnline: true, requestBusy: true), .wait)
        XCTAssertEqual(p.next(now: 10, observable: true, connected: false, displayOnline: false, requestBusy: true), .wait)
        XCTAssertEqual(p.next(now: 20, observable: true, connected: false, displayOnline: false, requestBusy: true), .failed)
    }
    func testUnknownSnapshotCannotReportSuccess() {
        var p = DisconnectionPolicy(); p.start(now: 0)
        XCTAssertEqual(p.next(now: 0, observable: false, connected: false, displayOnline: false, requestBusy: false), .wait)
        XCTAssertEqual(p.next(now: 20, observable: false, connected: false, displayOnline: false, requestBusy: false), .failed)
    }
    func testRetriesAreBounded() {
        var p = DisconnectionPolicy(); p.start(now: 0)
        for time in [0.0, 4, 8] {
            XCTAssertEqual(p.next(now: time, observable: true, connected: true, displayOnline: true, requestBusy: false), .send)
            p.requestFinished(now: time + 1)
        }
        XCTAssertEqual(p.next(now: 12, observable: true, connected: true, displayOnline: true, requestBusy: false), .failed)
    }
}
