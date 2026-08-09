import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ScreenshotStore()
    private let snippets = SnippetStore()
    private lazy var controller = NotchController(store: store, snippets: snippets)

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateOtherInstances()
        NSApp.setActivationPolicy(.accessory)
        // Флаги экспериментов читаются при сборке состояния шторки — значения
        // по умолчанию должны быть на месте раньше неё.
        Experiments.registerDefaults()
        // Без главного меню в окнах приложения не работают ни ⌘V, ни ⌘A.
        AppMenu.install()
        // Сначала окна: обращение к папке скриншотов может упереться
        // в диалог TCC, и шторка должна быть готова до этого.
        controller.start()
        store.start()
        snippets.start()
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
