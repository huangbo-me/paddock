import Foundation
import CryptoKit

public enum CommerceError: String, LocalizedError {
    case invalidLicense = "激活码无效，请检查后重试。"
    case unavailable = "暂时无法读取激活状态，请重试。"
    case alreadyStarted = "这台 Mac 已使用过试用。"
    case invalidConfiguration = "无法激活，请重新安装最新版。"
    public var errorDescription: String? { rawValue }
}
public struct LicensePayload: Codable, Equatable {
    public let schema: Int
    public let product: String
    public let majorVersion: Int
    public let licenseID: String
    public let issuedAt: Int64
    public init(licenseID: String, issuedAt: Int64, majorVersion: Int) {
        schema = 1; product = "paddock"; self.majorVersion = majorVersion
        self.licenseID = licenseID; self.issuedAt = issuedAt
    }
}
public struct LicenseVerifier {
    private let key: Curve25519.Signing.PublicKey
    private let major: Int
    public init(publicKey: Data, commercialMajor: Int) throws {
        guard commercialMajor > 0 else { throw CommerceError.invalidConfiguration }
        key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey); major = commercialMajor
    }
    public func verify(_ code: String, now: Double) throws -> LicensePayload {
        guard code.utf8.count <= 8192, now.isFinite else { throw CommerceError.invalidLicense }
        let parts = code.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "PD1",
              let payload = Data(base64Encoded: String(parts[1])), payload.count <= 4096,
              let signature = Data(base64Encoded: String(parts[2])), signature.count == 64,
              key.isValidSignature(signature, for: payload),
              let license = try? JSONDecoder().decode(LicensePayload.self, from: payload),
              license.schema == 1, license.product == "paddock", license.majorVersion == major,
              !license.licenseID.isEmpty, license.licenseID.utf8.count <= 128,
              license.issuedAt > 0, Double(license.issuedAt) <= now + 300 else { throw CommerceError.invalidLicense }
        return license
    }
}
public enum EntitlementStatus: Equatable {
    case notStarted, trial(daysRemaining: Int), licensed(id: String), expired, clockChanged, unavailable
    public var entitled: Bool {
        switch self { case .trial, .licensed: return true; default: return false }
    }
}
public struct TrialRecord: Codable, Equatable {
    public let startedAt: Double
    public var lastSeenAt: Double
    public init(startedAt: Double, lastSeenAt: Double) { self.startedAt = startedAt; self.lastSeenAt = lastSeenAt }
    public func status(now: Double) -> EntitlementStatus {
        guard now.isFinite, startedAt.isFinite, lastSeenAt.isFinite, startedAt > 0, lastSeenAt >= startedAt else { return .unavailable }
        guard now >= lastSeenAt - 300, now >= startedAt - 300 else { return .clockChanged }
        let remaining = 14 * 86400 - (max(now, lastSeenAt) - startedAt)
        return remaining > 0 ? .trial(daysRemaining: Int(ceil(remaining / 86400))) : .expired
    }
}
public enum PurchaseLink {
    public static func validated(_ value: String) -> URL? {
        guard let url = URL(string: value), url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(), ["afdian.com", "afdian.net"].contains(host),
              url.user == nil, url.password == nil, url.port == nil || url.port == 443,
              url.path.split(separator: "/").count >= 2 else { return nil }
        return url
    }
}
public enum CommerceAccess {
    // External EDID can belong to a dummy plug or software display. Only an online
    // built-in panel is positive evidence here; ambiguity preserves headless recovery.
    public static func isIndependentUsableScreen(builtIn: Bool, anchor: Bool, sidecar: Bool, classificationKnown: Bool) -> Bool {
        classificationKnown && builtIn && !anchor && !sidecar
    }
    public static func allowsAutomaticConnection(entitled: Bool, paired: Bool, headless: Bool, independentDisplay: Bool) -> Bool {
        entitled || (paired && headless && !independentDisplay)
    }
}
public struct CommerceConfiguration: Codable {
    public let commercialMajor: Int
    public let publicKey: String
    public var purchaseURL: String
    public init(commercialMajor: Int, publicKey: String, purchaseURL: String) {
        self.commercialMajor = commercialMajor; self.publicKey = publicKey; self.purchaseURL = purchaseURL
    }
    public func verifier() throws -> LicenseVerifier {
        guard let data = Data(base64Encoded: publicKey) else { throw CommerceError.invalidConfiguration }
        return try LicenseVerifier(publicKey: data, commercialMajor: commercialMajor)
    }
}
