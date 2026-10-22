import Foundation

public protocol CommerceStorage {
    func read() throws -> Data?
    func write(_ data: Data) throws
}
private struct CommerceRecord: Codable {
    var schema = 1
    var trial: TrialRecord?
    var licenseCode: String?
    var licenseVerifiedAt: Double?
}
public final class CommerceEngine {
    private let storage: CommerceStorage
    private let verifier: LicenseVerifier
    private var record = CommerceRecord()
    private var loadFailed = false
    public init(storage: CommerceStorage, verifier: LicenseVerifier) {
        self.storage = storage; self.verifier = verifier
        do {
            if let data = try storage.read() {
                let decoded = try JSONDecoder().decode(CommerceRecord.self, from: data)
                guard decoded.schema == 1 else { throw CommerceError.unavailable }
                record = decoded
            }
        } catch { loadFailed = true }
    }
    public func status(now: Double) -> EntitlementStatus {
        guard !loadFailed else { return .unavailable }
        if let code = record.licenseCode {
            guard let payload = try? verifier.verify(code, now: max(now, record.licenseVerifiedAt ?? now)) else { return .unavailable }
            return .licensed(id: payload.licenseID)
        }
        return record.trial?.status(now: now) ?? .notStarted
    }
    public func startTrial(now: Double) throws {
        guard !loadFailed, now.isFinite, now > 0 else { throw CommerceError.unavailable }
        guard record.trial == nil, record.licenseCode == nil else { throw CommerceError.alreadyStarted }
        var next = record; next.trial = TrialRecord(startedAt: now, lastSeenAt: now)
        try persist(next)
    }
    public func activate(_ code: String, now: Double) throws {
        guard !loadFailed else { throw CommerceError.unavailable }
        _ = try verifier.verify(code, now: now)
        var next = record; next.licenseCode = code.trimmingCharacters(in: .whitespacesAndNewlines); next.licenseVerifiedAt = now
        try persist(next)
    }
    public func checkpoint(now: Double) throws {
        guard !loadFailed else { throw CommerceError.unavailable }
        guard now.isFinite, var trial = record.trial, record.licenseCode == nil, now >= trial.lastSeenAt + 60 else { return }
        trial.lastSeenAt = now
        var next = record; next.trial = trial; try persist(next)
    }
    private func persist(_ next: CommerceRecord) throws {
        // Do not report success until the durable write has completed.
        try storage.write(JSONEncoder().encode(next)); record = next
    }
}
