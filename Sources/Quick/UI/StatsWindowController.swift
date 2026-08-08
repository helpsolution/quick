import AppKit
import SwiftUI

/// Отдельное окно статистики. Открывается из настроек и только вручную —
/// в обычной работе архив событий не читается вовсе.
@MainActor
final class StatsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        // Дописываем накопленное до того, как окно начнёт читать архив.
        EventLog.shared.flushPending()

        // Пересоздаём содержимое при каждом открытии: срез должен быть свежим,
        // а не тем, что посчитали в прошлый раз.
        let window = existingWindow ?? makeWindow()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private var existingWindow: NSWindow? {
        guard let window, window.isVisible else { return nil }
        return window
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: StatsView.windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Статистика"
        window.isReleasedWhenClosed = false
        window.delegate = self

        let hosting = NSHostingView(rootView: StatsView())
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        window.setContentSize(hosting.fittingSize)
        window.center()
        return window
    }

    /// Закрытое окно отпускаем целиком: следующее открытие соберёт свежий срез.
    /// Фокус, в отличие от настроек, не прячем — окно статистики закрывают,
    /// когда настройки ещё открыты.
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
