import Foundation
import CryptoKit
import Darwin

enum ToolError: Error { case usage, invalidCount, unsafePermissions, existingDestination, writeFailed }
func createOnly(_ data: Data, at path: String, mode: mode_t) throws {
    let descriptor = open(path, O_WRONLY | O_CREAT | O_EXCL, mode)
    guard descriptor >= 0 else { throw ToolError.existingDestination }
    defer { close(descriptor) }
    guard fchmod(descriptor, mode) == 0 else { throw ToolError.writeFailed }
    try data.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
            let written = Darwin.write(descriptor, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
            guard written > 0 else { throw ToolError.writeFailed }; offset += written
        }
    }
    guard fsync(descriptor) == 0 else { throw ToolError.writeFailed }
}
func readSigningKey(_ path: String) throws -> Curve25519.Signing.PrivateKey {
    let attrs = try FileManager.default.attributesOfItem(atPath: path)
    guard let permissions = attrs[.posixPermissions] as? NSNumber,
          permissions.intValue & 0o077 == 0 else { throw ToolError.unsafePermissions }
    return try Curve25519.Signing.PrivateKey(rawRepresentation: Data(contentsOf: URL(fileURLWithPath: path)))
}
@main enum LicenseTool {
    static func main() {
        do { try run(Array(CommandLine.arguments.dropFirst())) }
        catch {
            fputs("License tool failed: \(error). No secret material is printed.\n", stderr)
            exit(1)
        }
    }
    static func run(_ args: [String]) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let command = args.first else { throw ToolError.usage }
        switch command {
        case "keygen":
            guard args.count == 3 else { throw ToolError.usage }
            guard !FileManager.default.fileExists(atPath: args[1]), !FileManager.default.fileExists(atPath: args[2]) else { throw ToolError.existingDestination }
            let key = Curve25519.Signing.PrivateKey()
            let config = CommerceConfiguration(commercialMajor: 1, publicKey: key.publicKey.rawRepresentation.base64EncodedString(), purchaseURL: "")
            try createOnly(key.rawRepresentation, at: args[1], mode: 0o600)
            try createOnly(encoder.encode(config), at: args[2], mode: 0o644)
            print("Signing key and public configuration created. Keep the private key backed up outside distributed packages.")
        case "issue":
            guard args.count == 4, let count = Int(args[2]), (1...10000).contains(count) else { throw ToolError.invalidCount }
            let key = try readSigningKey(args[1])
            var codes: [String] = []
            for _ in 0..<count {
                let payload = LicensePayload(licenseID: UUID().uuidString, issuedAt: Int64(Date().timeIntervalSince1970), majorVersion: 1)
                let data = try encoder.encode(payload)
                codes.append("PD1." + data.base64EncodedString() + "." + (try key.signature(for: data)).base64EncodedString())
            }
            try createOnly(Data((codes.joined(separator: "\n") + "\n").utf8), at: args[3], mode: 0o600)
            print("Issued \(count) unique offline licenses. Import one line per automatic reply in Afdian.")
        case "verify":
            guard args.count == 3 else { throw ToolError.usage }
            let config = try JSONDecoder().decode(CommerceConfiguration.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
            let lines = try String(contentsOfFile: args[2], encoding: .utf8).split(whereSeparator: \.isNewline)
            guard !lines.isEmpty else { throw CommerceError.invalidLicense }
            let verifier = try config.verifier()
            for code in lines { _ = try verifier.verify(String(code), now: Date().timeIntervalSince1970) }
            print("Verified \(lines.count) licenses; no activation performed.")
        case "set-purchase-url":
            guard args.count == 3, PurchaseLink.validated(args[2]) != nil else { throw ToolError.usage }
            let url = URL(fileURLWithPath: args[1])
            var config = try JSONDecoder().decode(CommerceConfiguration.self, from: Data(contentsOf: url))
            _ = try config.verifier(); config.purchaseURL = args[2]
            try encoder.encode(config).write(to: url, options: .atomic)
            print("Purchase URL updated. Rebuild and distribute the updated app.")
        default: throw ToolError.usage
        }
    }
}
