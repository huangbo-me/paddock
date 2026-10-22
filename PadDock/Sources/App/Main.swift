import AppKit
import SwiftUI

@main
enum PadDockMain {
    static func main() {
        if let index = CommandLine.arguments.firstIndex(of: "--verify-license-file") {
            do {
                guard CommandLine.arguments.count > index + 1,
                      let configURL = Bundle.main.url(forResource: "Commerce", withExtension: "json") else { throw CommerceError.invalidConfiguration }
                let config = try JSONDecoder().decode(CommerceConfiguration.self, from: Data(contentsOf: configURL))
                let code = try String(contentsOfFile: CommandLine.arguments[index + 1], encoding: .utf8)
                _ = try config.verifier().verify(code, now: Date().timeIntervalSince1970)
                print("License verified against bundled public key; no activation or display changes."); exit(0)
            } catch { fputs("License verification failed.\n", stderr); exit(1) }
        }
        if CommandLine.arguments.contains("--self-check") {
            let native = PDNative(); let snapshot = native.snapshot()
            let report: [String: Any] = [
                "apiAvailable": snapshot["available"] as? Bool ?? false,
                "usbIPadCount": (snapshot["usb"] as? [Any])?.count ?? 0,
                "sidecarDeviceCount": (snapshot["devices"] as? [Any])?.count ?? 0,
                "onlineDisplayCount": (snapshot["displays"] as? [Any])?.count ?? 0,
                "createdAnchor": native.anchorID != 0,
                "readOnly": true
            ]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), let text = String(data: data, encoding: .utf8) { print(text) }
            return
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var controller: Controller!
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           let other = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first(where: { $0.processIdentifier != getpid() }) {
            other.activate(options: [.activateAllWindows]); NSApp.terminate(nil); return
        }
        NSApp.setActivationPolicy(.accessory)
        controller = Controller()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "ipad.landscape", accessibilityDescription: "PadDock")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "PadDock · iPad 自动随航"
        let menu = NSMenu(); menu.delegate = self; statusItem.menu = menu
        controller.onChange = { [weak self] in self?.statusItem.button?.toolTip = "PadDock · \(self?.controller.statusTitle ?? "")" }
        // Avoid opening a window on login for an already-configured user.
        if controller.settings.pairing == nil || !controller.legacy.isEmpty { showWindow() }
    }
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: controller.statusTitle, action: nil, keyEquivalent: ""); status.isEnabled = false; menu.addItem(status)
        menu.addItem(.separator())
        add("打开 PadDock…", #selector(showWindow), to: menu, key: "o")
        add("购买与激活…", #selector(commerce), to: menu)
        if controller.legacy.isEmpty && controller.settings.pairing != nil {
            add("立即连接", #selector(connect), to: menu)
            add(controller.settings.paused ? "恢复自动连接" : "暂停自动连接", #selector(pause), to: menu)
            add("断开 iPad…", #selector(disconnect), to: menu)
        }
        menu.addItem(.separator())
        add("导出诊断…", #selector(diagnostics), to: menu)
        add("退出 PadDock", #selector(quit), to: menu, key: "q")
    }
    private func add(_ title: String, _ selector: Selector, to menu: NSMenu, key: String = "") {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key); item.target = self; menu.addItem(item)
    }
    @objc func showWindow() {
        if window == nil {
            let view = Dashboard(app: controller)
            let hosting = NSHostingController(rootView: view)
            let created = NSWindow(contentViewController: hosting)
            created.title = "PadDock"; created.setContentSize(NSSize(width: 900, height: 700))
            created.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            created.titlebarAppearsTransparent = true; created.isReleasedWhenClosed = false
            created.minSize = NSSize(width: 860, height: 680); created.center(); window = created
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func commerce() { controller.selectedPage = 3; showWindow() }
    @objc private func connect() { controller.connectNow() }
    @objc private func pause() { controller.togglePause() }
    @objc private func disconnect() { controller.disconnect() }
    @objc private func diagnostics() { controller.exportDiagnostics() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller else { return .terminateNow }
        return controller.canQuit() ? .terminateNow : .terminateCancel
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
