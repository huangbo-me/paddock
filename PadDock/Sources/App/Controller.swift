import AppKit
import Combine
import ServiceManagement

final class Controller: ObservableObject {
    let native = PDNative()
    let commerce = CommerceStore()
    @Published var recoveryProtected = false
    @Published var commerceBlocksAutomation = false
    @Published var settings = AppSettings()
    @Published var devices: [Device] = []
    @Published var usbSerials: [String] = []
    @Published var selectedID = ""
    @Published var action: ConnectionAction = .unpaired
    @Published var errorMessage: String?
    @Published var note = "连接你的 iPad。"
    @Published var busy = false
    @Published var legacy: [LegacyService] = []
    @Published var anchorOnline = false
    @Published var loginEnabled = false
    @Published var needsLoginApproval = false
    @Published var apiAvailable = true
    @Published var selectedPage = 0
    private var policy = ConnectionPolicy(pairing: nil)
    private var timer: Timer?
    private var events: [String] = []
    private var generation = 0
    private var nativeGate = NativeOperationGate()
    private var pairingRequestSucceeded = false
    private var legacyDiscoveryFailed = false
    private var tickRunning = false
    private var pendingPairing: Pairing?
    private var pairDeadline: Double = 0
    private var pairStableSince: Double?
    private var manualUntil: Double = 0
    private var lastAction: ConnectionAction?
    private var lastMirrorError: String?
    private var legacyCheckAt: Double = 0
    var onChange: (() -> Void)?
    var pairedDevice: Device? { devices.first { $0.id == settings.pairing?.sidecarID } }
    var installed: Bool {
        let path = Bundle.main.bundleURL.standardizedFileURL.path
        return path.hasPrefix("/Applications/") || path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path + "/")
    }
    var statusTitle: String {
        if legacyDiscoveryFailed { return "暂时无法检查后台服务" }
        if !legacy.isEmpty { return "旧版服务正在运行" }
        if pendingPairing != nil { return "正在连接 iPad" }
        if !apiAvailable { return "此系统暂不兼容" }
        switch action {
        case .unpaired: return "准备连接你的 iPad"
        case .paused: return "自动连接已暂停"
        case .waitingForCable: return "等待插入数据线"
        case .waitingForUnlock: return "等待解锁 Mac"
        case .waitingForDevice: return "等待 iPad 就绪"
        case .connect, .connecting: return "正在连接 iPad"
        case .verifying: return "正在确认画面连接"
        case .connected: return "iPad 已连接"
        case .retryLater: return "连接中断，稍后重试"
        }
    }
    var statusSubtitle: String {
        if !legacy.isEmpty { return "当前连接由原型后台任务维护。接管前，PadDock 仅查看状态。" }
        if action == .connected { return "已通过数据线连接" }
        if action == .waitingForDevice { return "请解锁 iPad，确认已信任此 Mac，并使用同一 Apple 账户。" }
        if commerceBlocksAutomation { return "开始试用或激活后，即可自动连接。" }
        if action == .paused { return "点击恢复，即可继续自动连接。" }
        return note
    }
    init() {
        do { settings = try AppFiles.load() }
        catch { settings.paused = true; errorMessage = "无法读取本地设置。\(error.localizedDescription)" }
        policy = ConnectionPolicy(pairing: settings.pairing)
        commerce.onChange = { [weak self] in self?.policy.reset(); self?.tick() }
        refreshLegacy()
        native.usbChanged = { [weak self] in self?.tick() }
        native.startUSBMonitoring()
        refreshLoginStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }
    private func log(_ message: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        events.append("\(time)  \(message)")
        if events.count > 80 { events.removeFirst(events.count - 80) }
    }
    private func save() {
        do { try AppFiles.save(settings) }
        catch { errorMessage = "设置未能保存：\(error.localizedDescription)" }
    }
    func tick() {
        guard !tickRunning else { return }; tickRunning = true
        defer { tickRunning = false; onChange?() }
        let now = ProcessInfo.processInfo.systemUptime
        commerce.refresh()
        let snapshot = native.snapshot()
        devices = (snapshot["devices"] as? [[String: Any]] ?? []).compactMap(Device.init)
        usbSerials = (snapshot["usb"] as? [[String: Any]] ?? []).compactMap { $0["serial"] as? String }
        apiAvailable = snapshot["available"] as? Bool ?? false
        let displays = snapshot["displays"] as? [[String: Any]] ?? []
        anchorOnline = native.anchorID != 0 && displays.contains { ($0["id"] as? NSNumber)?.uint32Value == native.anchorID }
        if now > legacyCheckAt && !busy { refreshLegacy(); legacyCheckAt = now + 10 }
        if selectedID.isEmpty || !devices.contains(where: { $0.id == selectedID }) { selectedID = devices.first?.id ?? "" }
        guard legacy.isEmpty, !legacyDiscoveryFailed, apiAvailable else { return }
        if let pending = pendingPairing {
            let device = devices.first { $0.id == pending.sidecarID }
            if Set(usbSerials) != [pending.usbSerial] { finishPairing(error: "配对期间 USB 设备发生变化，请只连接目标 iPad 后重试。"); return }
            if pairingRequestSucceeded && device?.connected == true && device?.online == true && device?.transport == 2 {
                if pairStableSince == nil { pairStableSince = now }
                if PairingCandidate.canCommit(candidateSerial: pending.usbSerial, usbSerials: usbSerials, requestSucceeded: pairingRequestSucceeded, connectedUSBDisplay: true, stableSeconds: now - (pairStableSince ?? now)) {
                    settings.pairing = pending; settings.paused = false
                    policy = ConnectionPolicy(pairing: pending)
                    generation += 1; pendingPairing = nil; busy = false; save()
                    note = "已绑定这台 iPad。以后插上线即可自动连接。"; log("设备配对成功")
                }
            } else { pairStableSince = nil }
            if pendingPairing != nil && now > pairDeadline { finishPairing(error: "没有验证到稳定的 USB 随航画面，未保存配对。请检查系统显示器设置。"); return }
            if pendingPairing != nil { return }
        }
        guard !busy, !nativeGate.isBusy else { return }
        policy.pairing = settings.pairing
        // Unknown display classification keeps recovery available; never infer a safe screen from it.
        let sidecarIDs = Set(devices.filter { $0.connected }.map(\.displayID))
        let classified = apiAvailable && !sidecarIDs.contains(0)
        let independent = classified && displays.contains {
            guard let id = ($0["id"] as? NSNumber)?.uint32Value else { return false }
            return CommerceAccess.isIndependentUsableScreen(builtIn: ($0["builtIn"] as? Bool) == true,
                anchor: id == native.anchorID, sidecar: sidecarIDs.contains(id), classificationKnown: classified)
        }
        recoveryProtected = !commerce.entitled && settings.pairing != nil && settings.headless && !independent
        let permitted = CommerceAccess.allowsAutomaticConnection(entitled: commerce.entitled, paired: settings.pairing != nil, headless: settings.headless, independentDisplay: independent)
        commerceBlocksAutomation = !permitted && now > manualUntil
        policy.paused = settings.paused || (!settings.autoConnect && now > manualUntil) || commerceBlocksAutomation
        let locked = snapshot["locked"] as? Bool ?? true
        if settings.headless && settings.pairing != nil && native.anchorID == 0 && !policy.paused && !locked {
            if let error = native.createAnchor() { errorMessage = error; return }
            log("已创建无显示器支持屏幕")
        }
        if native.anchorID != 0, let pair = settings.pairing {
            if let error = native.mirrorAnchor(toDevice: pair.sidecarID) {
                if error != lastMirrorError { log("镜像配置暂未完成"); lastMirrorError = error }
            } else { lastMirrorError = nil }
        }
        let d = pairedDevice
        var observation = Observation(usbSerials: usbSerials, targetAvailable: d != nil, connected: d?.connected ?? false, displayOnline: d?.online ?? false, locked: locked)
        observation.usbTransport = d?.transport == 2
        action = policy.next(observation: observation, now: now)
        if lastAction != action { log("连接状态：\(action.rawValue)"); lastAction = action }
        if action == .connect, let pair = settings.pairing {
            guard let operation = nativeGate.begin(.connect) else { return }
            generation += 1; let token = generation
            native.connectDevice(pair.sidecarID) { [weak self] error in
                guard let self else { return }
                let followup = self.nativeGate.finish(operation, succeeded: error == nil)
                if followup == .disconnect { self.performDisconnect(pair); return }
                guard self.generation == token else { self.tick(); return }
                self.policy.connectionFinished(success: error == nil, now: ProcessInfo.processInfo.systemUptime)
                if let error { self.errorMessage = error; self.log("USB 连接失败") }
                else { self.log("收到连接回调，等待显示器稳定") }
                self.tick()
            }
        }
        if action == .connected { errorMessage = nil }
    }
    func pairSelectedDevice() {
        guard requireEntitlement() else { return }
        guard legacy.isEmpty, !legacyDiscoveryFailed, !busy, !nativeGate.isBusy, apiAvailable else { return }
        guard PairingCandidate.valid(usbSerials: usbSerials, selectedID: selectedID, availableIDs: devices.map(\.id)),
              let device = devices.first(where: { $0.id == selectedID }), let usb = usbSerials.first else {
            errorMessage = "请只连接一台 iPad，并从列表中选择它。使用支持数据传输的线缆。"; return
        }
        let candidate = Pairing(name: device.name, usbSerial: usb, sidecarID: device.id)
        guard let operation = nativeGate.begin(.connect) else { return }
        busy = true; pendingPairing = candidate; pairStableSince = nil; pairingRequestSucceeded = false
        pairDeadline = ProcessInfo.processInfo.systemUptime + 35
        errorMessage = nil; generation += 1; let token = generation
        native.connectDevice(device.id) { [weak self] error in
            guard let self else { return }
            let followup = self.nativeGate.finish(operation, succeeded: error == nil)
            if followup == .disconnect { self.performDisconnect(candidate); return }
            guard self.generation == token else { self.tick(); return }
            if let error { self.finishPairing(error: error) }
            else { self.pairingRequestSucceeded = true; self.tick() }
        }
    }
    private func finishPairing(error: String) {
        generation += 1; pendingPairing = nil; pairStableSince = nil; busy = false
        errorMessage = error; log("配对未完成，未保存设备标识")
    }
    func togglePause() {
        guard legacy.isEmpty, !legacyDiscoveryFailed, !busy else { return }
        settings.paused.toggle(); generation += 1; policy.reset(); action = settings.paused ? .paused : .connecting; save(); tick()
    }
    func connectNow() {
        guard legacy.isEmpty, !legacyDiscoveryFailed, !busy, !nativeGate.isBusy, settings.pairing != nil else { return }
        settings.paused = false; manualUntil = ProcessInfo.processInfo.systemUptime + 120
        policy.reset(); save(); tick()
    }
    func disconnect() {
        guard legacy.isEmpty, !legacyDiscoveryFailed, !busy, let pair = settings.pairing else { return }
        guard confirm("断开 iPad？", "断开后将暂停自动连接。如果只用 iPad 显示，请先接回其他显示器。", button: "暂停并断开") else { return }
        settings.paused = true; generation += 1; policy.reset(); action = .paused; save()
        if nativeGate.isBusy { nativeGate.requestDisconnect(); note = "等待当前连接请求结束后断开。" }
        else { performDisconnect(pair) }
        tick()
    }
    private func performDisconnect(_ pair: Pairing) {
        guard let operation = nativeGate.begin(.disconnect) else { return }
        native.disconnectDevice(pair.sidecarID) { [weak self] error in
            guard let self else { return }
            _ = self.nativeGate.finish(operation, succeeded: error == nil)
            self.errorMessage = error; self.tick()
        }
    }
    func setAutoConnect(_ enabled: Bool) { settings.autoConnect = enabled; save(); tick() }
    func setHeadless(_ enabled: Bool) {
        guard legacy.isEmpty, !legacyDiscoveryFailed, !busy, !nativeGate.isBusy else { return }
        if enabled {
            guard requireEntitlement() else { return }
            guard settings.pairing != nil else { errorMessage = "请先绑定并验证一台 iPad。"; return }
            guard confirm("仅用 iPad 显示？", "开启后可以拔掉其他显示器。画面可能短暂闪烁。", button: "开启") else { return }
            if let error = native.createAnchor() { errorMessage = error; return }
            settings.headless = true
        } else {
            if !native.canReleaseAnchor() { errorMessage = "请先接回其他显示器，再关闭此选项。"; return }
            settings.headless = false; native.releaseAnchor()
        }
        save(); tick()
    }
    func refreshLoginStatus() {
        loginEnabled = SMAppService.mainApp.status == .enabled
        needsLoginApproval = SMAppService.mainApp.status == .requiresApproval
    }
    func setLogin(_ enabled: Bool) {
        guard installed else { errorMessage = "请先把 PadDock 拖入「应用程序」并从那里打开，再开启登录启动。"; return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLoginStatus()
            if needsLoginApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { errorMessage = "登录启动设置未完成：\(error.localizedDescription)"; refreshLoginStatus() }
    }
    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
    func openDisplaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") { NSWorkspace.shared.open(url) }
    }
    @discardableResult func confirm(_ title: String, _ message: String, button: String) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = message; alert.alertStyle = .warning
        alert.addButton(withTitle: button); alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }
    func canQuit() -> Bool {
        if busy || nativeGate.isBusy { errorMessage = "正在完成操作，请稍后退出。"; return false }
        if native.anchorID != 0 && !native.canReleaseAnchor() {
            return confirm("退出会中断 iPad 画面", "请先接回其他显示器，避免退出后无法操作。", button: "仍然退出")
        }
        return true
    }
    func clearConfiguration() {
        guard !busy, !nativeGate.isBusy, !legacyDiscoveryFailed, legacy.isEmpty else { return }
        guard native.canReleaseAnchor() else { errorMessage = "请先接回其他显示器，再清理 PadDock。"; return }
        guard confirm("重置设置？", "将移除 iPad 配对并恢复默认设置，试用和购买记录不变。", button: "重置") else { return }
        do {
            if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval { try SMAppService.mainApp.unregister() }
            if FileManager.default.fileExists(atPath: AppFiles.settings.path) { try FileManager.default.removeItem(at: AppFiles.settings) }
            generation += 1; native.releaseAnchor(); settings = AppSettings(); policy = ConnectionPolicy(pairing: nil)
            note = "设置已重置。"; refreshLoginStatus(); tick()
        } catch { errorMessage = "清理未完成：\(error.localizedDescription)" }
    }
    func exportDiagnostics() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "PadDock-diagnostics.txt"
        panel.title = "导出问题报告"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let info = """
        PadDock 0.2.1 internal beta
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        API available: \(apiAvailable)
        Paired: \(settings.pairing != nil)
        USB iPad count: \(usbSerials.count)
        State: \(action.rawValue)
        Virtual support requested/online: \(settings.headless)/\(anchorOnline)
        Login enabled: \(loginEnabled)
        Legacy service count: \(legacy.count)
        Device identifiers, device names, user paths and screenshots are omitted.

        \(events.joined(separator: "\n"))
        """
        do { try info.write(to: url, atomically: true, encoding: .utf8); note = "问题报告已导出。" }
        catch { errorMessage = "无法保存诊断：\(error.localizedDescription)" }
    }

    func migrateLegacy() {
        guard requireEntitlement() else { return }
        guard !busy, !nativeGate.isBusy, !legacyDiscoveryFailed, !legacy.isEmpty else { return }
        guard legacy.allSatisfy({ FileManager.default.fileExists(atPath: $0.plist.path) }) else {
            errorMessage = "检测到旧任务仍已加载，但找不到它的启动配置。为保证能够回滚，暂不接管；请先恢复旧任务的 plist 文件。"; return
        }
        guard installed else { errorMessage = "请先将 PadDock 拖入「应用程序」，从那里打开后再接管旧版。"; return }
        guard let pair = AppFiles.legacyPairing(devices: devices), usbSerials.contains(pair.usbSerial),
              let device = devices.first(where: { $0.id == pair.sidecarID }), device.connected, device.online, device.transport == 2 else {
            errorMessage = "请先让旧版通过 USB 正常连接 iPad，再进行接管。"; return
        }
        guard confirm("使用原有设置？", "将保留 iPad 配对并开启登录启动。切换期间画面可能短暂中断。", button: "继续") else { return }
        do {
            if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            refreshLoginStatus()
            guard loginEnabled else { errorMessage = "请先在系统登录项中批准 PadDock，再重试接管。"; return }
        } catch { errorMessage = "登录启动注册失败，旧版未改动：\(error.localizedDescription)"; return }
        if let error = native.createAnchor() { errorMessage = error; return }
        if let error = native.mirrorAnchor(toDevice: pair.sidecarID) { errorMessage = error; return }
        busy = true; errorMessage = nil
        let services = legacy
        verifyMigration(pair) { [weak self] ready in
            guard let self else { return }
            guard ready else { self.busy = false; self.errorMessage = "新支持屏幕或 USB 画面未稳定，旧版保持运行。"; return }
            let backup = AppFiles.root.appendingPathComponent("LegacyBackup/\(UUID().uuidString)", isDirectory: true)
            var stopped: [LegacyService] = []
            var moved: [(URL, URL)] = []
            func rollback(_ reason: String) {
                var rollbackOK = true
                for (original, archived) in moved.reversed() {
                    do { try FileManager.default.moveItem(at: archived, to: original) } catch { rollbackOK = false }
                }
                for service in stopped {
                    if self.launchctl(["bootstrap", "gui/\(getuid())", service.plist.path]) != 0 { rollbackOK = false }
                }
                self.busy = false; self.refreshLegacy()
                self.errorMessage = rollbackOK ? "接管未完成，旧任务已重新加载。\(reason)" : "接管未完成，旧任务恢复未完全成功。请保留 PadDock 运行并接回实体显示器；备份位于 PadDock 支持目录。"
                // Keep replacement anchor alive even on failure.
                self.log(rollbackOK ? "迁移回滚完成，等待画面恢复" : "迁移需要人工恢复")
            }
            do {
                try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
                for service in services {
                    let domain = "gui/\(getuid())/\(service.label)"
                    if self.launchctl(["print", domain]) == 0 {
                        guard self.launchctl(["bootout", domain]) == 0 else { throw NSError(domain: "PadDock", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法停用旧版任务。"]) }
                        stopped.append(service)
                    }
                    let destination = backup.appendingPathComponent(service.plist.lastPathComponent)
                    try FileManager.default.moveItem(at: service.plist, to: destination)
                    moved.append((service.plist, destination))
                }
            } catch { rollback(error.localizedDescription); return }
            self.verifyMigration(pair) { ready in
                guard ready else { rollback("停用旧任务后画面未稳定。"); return }
                do {
                    var updated = self.settings
                    updated.pairing = pair; updated.autoConnect = true; updated.headless = true; updated.paused = false
                    try AppFiles.save(updated)
                    self.settings = updated; self.policy = ConnectionPolicy(pairing: pair)
                    self.legacy = []; self.legacyCheckAt = 0; self.busy = false
                    self.note = "接管完成。旧版任务已备份，PadDock 会在登录后启动。"
                    self.log("旧版迁移完成"); self.tick()
                } catch { rollback(error.localizedDescription) }
            }
        }
    }
    private func verifyMigration(_ pair: Pairing, completion: @escaping (Bool) -> Void) {
        let deadline = ProcessInfo.processInfo.systemUptime + 15
        sampleMigration(pair, deadline: deadline, stableSince: nil, completion: completion)
    }
    private func sampleMigration(_ pair: Pairing, deadline: Double, stableSince: Double?, completion: @escaping (Bool) -> Void) {
        let now = ProcessInfo.processInfo.systemUptime
        let mirrorError = native.mirrorAnchor(toDevice: pair.sidecarID)
        let snapshot = native.snapshot()
        let displays = snapshot["displays"] as? [[String: Any]] ?? []
        let device = (snapshot["devices"] as? [[String: Any]] ?? []).compactMap(Device.init).first { $0.id == pair.sidecarID }
        let serials = (snapshot["usb"] as? [[String: Any]] ?? []).compactMap { $0["serial"] as? String }
        let anchor = displays.first { ($0["id"] as? NSNumber)?.uint32Value == native.anchorID }
        let online = native.anchorID != 0 && anchor != nil
        let mirror = mirrorError == nil && device?.displayID != 0 && (anchor?["mirrorOf"] as? NSNumber)?.uint32Value == device?.displayID
        let usb = serials.contains(pair.usbSerial)
        let picture = device?.connected == true && device?.online == true && device?.transport == 2
        let stable = online && mirror && usb && picture ? (stableSince ?? now) : nil
        if MigrationSafety.verified(anchorOnline: online, mirrorMatches: mirror, usbPresent: usb, usbDisplayOnline: picture, stableSeconds: stable.map { now - $0 } ?? 0) { completion(true); return }
        if now >= deadline { completion(false); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.sampleMigration(pair, deadline: deadline, stableSince: stable, completion: completion)
        }
    }
    private func requireEntitlement() -> Bool {
        commerce.refresh()
        guard commerce.entitled else {
            selectedPage = 3; commerce.message = "请先开始 14 天试用或输入激活码。"; return false
        }
        return true
    }
    private func refreshLegacy() {
        do { legacy = try AppFiles.legacyServices(); legacyDiscoveryFailed = false }
        catch { legacyDiscoveryFailed = true; errorMessage = error.localizedDescription }
    }
    private func launchctl(_ arguments: [String]) -> Int32 {
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/bin/launchctl"); task.arguments = arguments
        task.standardOutput = FileHandle.nullDevice; task.standardError = FileHandle.nullDevice
        do { try task.run(); task.waitUntilExit(); return task.terminationStatus } catch { return -1 }
    }
}
