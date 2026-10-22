import Foundation
import Security

let args = CommandLine.arguments
precondition(args.count == 3 && args[1].hasPrefix("app.paddock.tests.upgrade."))
let storage = KeychainCommerceStorage(service: args[1])
switch args[2] {
case "create":
    try storage.write(Data("disposable-test-record".utf8))
case "read":
    do {
        _ = try storage.read()
        fputs("Unexpectedly accessed another test identity's record.\n", stderr)
        exit(2)
    } catch { print("Access requiring approval returned promptly without UI.") }
case "delete":
    let status = SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                               kSecAttrService as String: args[1]] as CFDictionary)
    guard status == errSecSuccess else { exit(3) }
default: exit(4)
}
