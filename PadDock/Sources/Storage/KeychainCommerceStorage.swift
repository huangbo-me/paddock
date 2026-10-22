import Foundation
import Security
import LocalAuthentication
#if SWIFT_PACKAGE
import PadDockCore
import PadDockKeychainSupport
#endif

public final class KeychainCommerceStorage: CommerceStorage {
    private let service: String
    private(set) var interactionAllowed = false
    public init(service: String = "app.paddock.commerce") { self.service = service }
    // Synchronous, explicitly initiated UI actions only. The same engine's later
    // timer checkpoints automatically return to noninteractive access.
    public func withUserInteraction<T>(_ action: () throws -> T) rethrows -> T {
        let previous = interactionAllowed
        interactionAllowed = true
        defer { interactionAllowed = previous }
        return try action()
    }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "offline-license-v1",
         kSecAttrSynchronizable as String: false]
    }
    public func read() throws -> Data? {
        var request = query
        request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        let context = LAContext(); context.interactionNotAllowed = !interactionAllowed
        request[kSecUseAuthenticationContext as String] = context
        var item: Unmanaged<CFTypeRef>?
        let result = PDKeychainRead(request as CFDictionary, &item, interactionAllowed)
        if result == errSecItemNotFound { return nil }
        guard result == errSecSuccess, let data = item?.takeRetainedValue() as? Data else { throw CommerceError.unavailable }
        return data
    }
    public func write(_ data: Data) throws {
        var request = query; let context = LAContext(); context.interactionNotAllowed = !interactionAllowed
        request[kSecUseAuthenticationContext as String] = context
        let update = PDKeychainUpdate(request as CFDictionary, [kSecValueData as String: data] as CFDictionary, interactionAllowed)
        if update == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data
            item[kSecUseAuthenticationContext as String] = context
            item[kSecAttrLabel as String] = "PadDock 授权与试用记录"
            guard PDKeychainAdd(item as CFDictionary, interactionAllowed) == errSecSuccess else { throw CommerceError.unavailable }
        } else if update != errSecSuccess { throw CommerceError.unavailable }
    }
}
