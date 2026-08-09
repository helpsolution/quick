import AppKit
import SwiftUI

/// Окно редактора заготовок. Как и настройки — единственное место, где Quick
/// забирает фокус: без фокуса не набрать текст.
@MainActor
final class SnippetsWindowController: NSObject, NSWindowDelegate {
    private let store: SnippetStore
    private var window: NSWindow?

    init(store: SnippetStore) {
        self.store = store
    }

    func show() {
        let window = existingWindow ?? makeWindow()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private var existingWindow: NSWindow? {
        guard let window, window.isVisible || window.contentView != nil else { return nil }
        return window
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SnippetsEditorView.windowSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Заготовки"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: SnippetsEditorView(store: store))
        window.setContentSize(SnippetsEditorView.windowSize)
        window.center()
        return window
    }

    /// Приложение фоновое: закрыли редактор — фокус возвращается туда, где
    /// пользователь работал.
    func windowWillClose(_ notification: Notification) {
        store.dropBlanks()
        NSApp.hide(nil)
    }
}
