import AppKit
import SwiftUI

/// Окно настроек — единственное место, где Quick забирает фокус. Шторка этого
/// не делает принципиально, но в настройках нужны обычные переключатели
/// и кнопки, а они требуют активного приложения.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let statsWindow = StatsWindowController()
    private let snippetsWindow: SnippetsWindowController

    init(snippets: SnippetStore) {
        snippetsWindow = SnippetsWindowController(store: snippets)
        super.init()
        observeContentChanges()
    }

    func show() {
        let window = existingWindow ?? makeWindow()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        fitToContent()
    }

    private var existingWindow: NSWindow? {
        guard let window, window.isVisible || window.contentView != nil else { return nil }
        return window
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quick"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let hosting = NSHostingView(rootView: SettingsView(
            onOpenStats: { [statsWindow] in statsWindow.show() },
            onOpenSnippets: { [snippetsWindow] in snippetsWindow.show() }
        ))
        window.contentView = hosting
        // Размер окна — по фактическому размеру содержимого, а не по числу,
        // угаданному на глаз.
        //
        // `sizingOptions = [.preferredContentSize]` для этого не годится: с ним
        // хостинг перестаёт считать `fittingSize`, и окно открывалось нулевой
        // ширины — то есть не открывалось вовсе.
        hosting.layoutSubtreeIfNeeded()
        window.setContentSize(hosting.fittingSize)
        window.center()
        return window
    }

    /// Строки в настройках появляются и исчезают: включили эксперимент, выдали
    /// разрешение. Окно должно идти за содержимым, иначе нижние кнопки уезжают
    /// под край.
    private func observeContentChanges() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(contentMayHaveChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(contentMayHaveChanged),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func contentMayHaveChanged() {
        MainActor.assumeIsolated { fitToContent() }
    }

    private func fitToContent() {
        guard let window, window.isVisible, let content = window.contentView else { return }
        // SwiftUI пересобирает дерево на следующем витке цикла — мерить нужно
        // после него, иначе получим прежний размер.
        DispatchQueue.main.async {
            content.layoutSubtreeIfNeeded()
            let size = content.fittingSize
            guard size.width > 0, size.height > 0, size != content.frame.size else { return }

            // Верхний край остаётся на месте: окно растёт вниз, а не прыгает
            // по экрану на каждый переключатель.
            let top = window.frame.maxY
            window.setContentSize(size)
            var frame = window.frame
            frame.origin.y = top - frame.height
            window.setFrame(frame, display: true)
        }
    }

    /// Приложение фоновое: после закрытия настроек фокус должен вернуться туда,
    /// где пользователь работал, а не остаться у Quick.
    func windowWillClose(_ notification: Notification) {
        NSApp.hide(nil)
    }
}
