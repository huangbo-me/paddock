import AppKit
import SwiftUI

// A standalone QA harness: no native display bridge and no persistent storage.
final class PreviewStorage: CommerceStorage {
    var data: Data?
    func read() throws -> Data? { data }
    func write(_ data: Data) throws { self.data = data }
}
@main enum PreviewMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = PreviewDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
final class PreviewDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let store = CommerceStore(storage: PreviewStorage())
        let view = ScrollView { CommerceView(store: store).padding(24) }
            .frame(width: 660, height: 740).background(Color(red: 0.96, green: 0.965, blue: 0.95))
            .preferredColorScheme(.light)
        let w = NSWindow(contentViewController: NSHostingController(rootView: view))
        w.title = "PadDock 授权界面预览（不影响当前连接）"
        w.styleMask = [.titled, .closable, .miniaturizable]; w.isReleasedWhenClosed = false
        w.center(); w.makeKeyAndOrderFront(nil); window = w
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
