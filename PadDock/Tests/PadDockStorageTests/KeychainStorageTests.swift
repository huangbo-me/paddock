import XCTest
import Security
import PadDockCore
@testable import PadDockStorage

final class KeychainStorageTests: XCTestCase {
    func testUserAuthorizationScopeCannotLeakToBackgroundAccess() {
        let store = KeychainCommerceStorage(service: "app.paddock.tests." + UUID().uuidString)
        XCTAssertFalse(store.interactionAllowed)
        XCTAssertThrowsError(try store.withUserInteraction {
            XCTAssertTrue(store.interactionAllowed)
            store.withUserInteraction { XCTAssertTrue(store.interactionAllowed) }
            XCTAssertTrue(store.interactionAllowed)
            throw CommerceError.unavailable
        })
        XCTAssertFalse(store.interactionAllowed)
    }
    func testIsolatedKeychainCreateReadUpdateAndReload() throws {
        let service = "app.paddock.tests." + UUID().uuidString
        let store = KeychainCommerceStorage(service: service)
        defer {
            // Delete only this test's random item, never the installed app's account.
            SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary)
        }
        XCTAssertNil(try store.read())
        try store.write(Data("first".utf8)); XCTAssertEqual(try store.read(), Data("first".utf8))
        try store.write(Data("updated".utf8)); XCTAssertEqual(try store.read(), Data("updated".utf8))
        let other = KeychainCommerceStorage(service: service)
        XCTAssertEqual(try other.read(), Data("updated".utf8))
    }
}
