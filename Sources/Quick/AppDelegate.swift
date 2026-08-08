import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ScreenshotStore()
    private lazy var controller = NotchController(store: store)

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateOtherInstances()
        NSApp.setActivationPolicy(.accessory)
        // Сначала окна: обращение к папке скриншотов может упереться
        // в диалог TCC, и шторка должна быть готова до этого.
        controller.start()
        store.start()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Перезапуск не должен оставлять вторую шторку на той же челке.
    private func terminateOtherInstances() {
        guard let identifier = Bundle.main.bundleIdentifier else { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .forEach { $0.terminate() }
    }
}
