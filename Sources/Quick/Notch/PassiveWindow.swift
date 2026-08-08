import AppKit

/// Окно, которое никогда не забирает фокус: пользователь наводится на чёлку,
/// копирует скриншот и вставляет его в приложение, которое осталось активным.
final class PassiveWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        // Полноэкранное приложение живёт в своём Space. Уровня строки меню там
        // не хватает, а .fullScreenAuxiliary привязал бы окно к Space владельца —
        // поэтому уровень выше и только .canJoinAllSpaces.
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }
}
