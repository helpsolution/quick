import AppKit
import ApplicationServices

/// Вставка в то приложение, где пользователь работает. Шторка фокус не
/// забирает принципиально, поэтому активным остаётся окно под ней — и ⌘V
/// достаётся именно ему.
enum Paster {
    /// Синтетические нажатия macOS отдаёт только приложениям из списка
    /// «Универсальный доступ». Без разрешения события молча пропадают, поэтому
    /// спрашиваем заранее: текст к этому моменту уже в буфере, и клик не
    /// пропадает зря в любом случае.
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Системный диалог показывается один раз на приложение — дальше остаётся
    /// только кнопка в настройках Quick.
    static func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    /// - Returns: `false`, если разрешения нет и вставки не будет.
    ///
    /// Проверять заранее, есть ли в активном приложении текстовое поле, мы
    /// пробовали — чтобы не получать системный щелчок, когда вставлять некуда.
    /// Отказались: `AXFocusedUIElement` возвращает не то же самое, что first
    /// responder. TextEdit с открытым документом отдаёт фокус как `AXWindow`,
    /// и проверка резала бы законную вставку — это хуже щелчка.
    @discardableResult
    static func pasteIntoFrontmostApp() -> Bool {
        guard isTrusted else { return false }
        // Приёмник читает буфер уже после того, как получит нажатие. Пауза в
        // один кадр даёт ему увидеть новое содержимое, а не прежнее.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { postCommandV() }
        return true
    }

    private static let keyV: CGKeyCode = 0x09

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        else { return }
        // Флаги задаём явно на обоих событиях: приёмник смотрит на состояние
        // модификаторов в самом событии, а не на историю нажатий.
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
