import AppKit

@main
enum Main {
    /// NSApplication держит делегата слабо — ссылку храним здесь.
    @MainActor static let delegate = AppDelegate()

    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
