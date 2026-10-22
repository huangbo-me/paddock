import AppKit
import Combine
import Security

final class CommerceStore: ObservableObject {
    @Published private(set) var status: EntitlementStatus = .unavailable
    @Published var message: String?
    @Published var activationInput = ""
    private let storage: CommerceStorage
    private var engine: CommerceEngine?
    private(set) var configuration: CommerceConfiguration?
    var onChange: (() -> Void)?
    var purchaseURL: URL? { configuration.flatMap { PurchaseLink.validated($0.purchaseURL) } }
    var entitled: Bool { status.entitled }
    var title: String {
        switch status {
        case .notStarted: return "免费试用 14 天"
        case .trial(let days): return "试用中 · 剩余 \(days) 天"
        case .licensed: return "已激活"
        case .expired: return "试用已结束"
        case .clockChanged: return "请检查 Mac 日期与时间"
        case .unavailable: return "暂时无法读取激活状态"
        }
    }
    init(storage: CommerceStorage = KeychainCommerceStorage()) { self.storage = storage; reload() }
    private func userAction(_ action: () -> Void) {
        if let keychain = storage as? KeychainCommerceStorage { keychain.withUserInteraction(action) }
        else { action() }
    }
    func authorizeAndReload() { userAction { reload() } }
    func reload() {
        do {
            guard let url = Bundle.main.url(forResource: "Commerce", withExtension: "json") else { throw CommerceError.invalidConfiguration }
            let config = try JSONDecoder().decode(CommerceConfiguration.self, from: Data(contentsOf: url))
            let verifier = try config.verifier()
            configuration = config; engine = CommerceEngine(storage: storage, verifier: verifier)
            message = nil; refresh()
        } catch { engine = nil; status = .unavailable; message = error.localizedDescription }
    }
    func refresh() {
        guard let engine else { return }
        let now = Date().timeIntervalSince1970
        var next = engine.status(now: now)
        if next != .unavailable {
            do { try engine.checkpoint(now: now); next = engine.status(now: now) }
            catch { next = .unavailable; message = error.localizedDescription }
        }
        if status != next { status = next; onChange?() }
    }
    func startTrial() {
        userAction { startTrialAuthorized() }
    }
    private func startTrialAuthorized() {
        guard let engine else { return }
        do { try engine.startTrial(now: Date().timeIntervalSince1970); message = "已开始试用。"; refresh(); onChange?() }
        catch { message = error.localizedDescription }
    }
    func activate() {
        userAction { activateAuthorized() }
    }
    private func activateAuthorized() {
        guard let engine else { return }
        do {
            try engine.activate(activationInput, now: Date().timeIntervalSince1970)
            activationInput = ""; message = "激活成功。"
            refresh(); onChange?()
        } catch { message = error.localizedDescription }
    }
    func openPurchase() {
        guard let url = purchaseURL else { message = "暂未开放购买。"; return }
        if !NSWorkspace.shared.open(url) { message = "无法打开浏览器，请稍后重试。" }
    }
}
