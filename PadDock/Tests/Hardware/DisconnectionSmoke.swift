import AppKit

// Explicit hardware test: connects the saved iPad, then leaves it disconnected and paused.
@main
enum DisconnectionSmoke {
    static func main() throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        func ensureExclusive() {
            precondition(NSRunningApplication.runningApplications(withBundleIdentifier: "app.paddock.beta").isEmpty,
                         "Another PadDock is running; hardware test is invalid")
        }
        ensureExclusive()
        let controller = Controller()
        guard let pair = controller.settings.pairing, controller.legacy.isEmpty,
              !controller.settings.headless else {
            fputs("Requires an existing pairing, no legacy jobs, and headless mode off.\n", stderr); exit(2)
        }
        func wait(_ seconds: Double, until condition: () -> Bool) -> Bool {
            let deadline = Date().addingTimeInterval(seconds)
            while Date() < deadline {
                ensureExclusive()
                controller.tick()
                if condition() { return true }
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
            return condition()
        }
        func assertOffline() {
            precondition(!controller.disconnectFailed, controller.errorMessage ?? "Disconnect failed")
            precondition(!controller.isConnected && controller.pairedDevice?.online != true)
            precondition(controller.settings.paused)
            precondition(controller.statusTitle == "iPad 已断开", controller.statusTitle)
            // Inject a late system connection after successful verification. The user's
            // disconnect intent must win even after the initial callback and offline window.
            controller.native.connectDevice(pair.sidecarID) { _ in }
            let deadline = Date().addingTimeInterval(12)
            while Date() < deadline {
                ensureExclusive()
                controller.tick()
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
            precondition(wait(25) { !controller.disconnecting && !controller.isConnected && controller.pairedDevice?.online != true })
            precondition(!controller.disconnectFailed, "Failed to suppress late reconnection")
        }
        controller.connectNow()
        guard wait(35, until: { controller.isConnected }) else {
            controller.beginDisconnection(pair)
            _ = wait(25) { !controller.disconnecting }
            fputs("Hardware connection did not become ready.\n", stderr); exit(1)
        }
        print("PASS: actual controller connected USB iPad")
        controller.beginDisconnection(pair)
        precondition(controller.disconnecting)
        precondition(wait(25) { !controller.disconnecting })
        assertOffline()
        print("PASS: verified offline and suppressed an injected late system connection")
        controller.connectNow()
        controller.beginDisconnection(pair)
        precondition(wait(25) { !controller.disconnecting })
        assertOffline()
        print("PASS: disconnect during connection; no late reconnection")
    }
}
