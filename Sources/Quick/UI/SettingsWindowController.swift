import AppKit
import SwiftUI

/// Окно настроек — единственное место, где Quick забирает фокус. Шторка этого
/// не делает принципиально, но в настройках нужны обычные переключатели
/// и кнопки, а они требуют активного приложения.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let statsWindow = StatsWindowController()

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
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quick"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let hosting = NSHostingView(rootView: SettingsView(
            onOpenStats: { [statsWindow] in statsWindow.show() }
        ))
        window.contentView = hosting
        // Размер окна — по фактическому размеру содержимого, а не по числу,
        // угаданному на глаз.
        hosting.layoutSubtreeIfNeeded()
        window.setContentSize(hosting.fittingSize)
        window.center()
        return window
    }

    /// Приложение фоновое: после закрытия настроек фокус должен вернуться туда,
    /// где пользователь работал, а не остаться у Quick.
    func windowWillClose(_ notification: Notification) {
        NSApp.hide(nil)
    }
}
