import AppKit
import SwiftUI

/// Мышиный слой поверх миниатюры. SwiftUI-модификатор `.onDrag` отдаёт ровно
/// один `NSItemProvider`, поэтому перетаскивание нескольких выбранных
/// скриншотов делается через AppKit — `beginDraggingSession` умеет много
/// элементов сразу. Клик ведёт этот же слой: свои жесты SwiftUI конфликтуют
/// с перехватом `mouseDown`.
struct DragSelectionView: NSViewRepresentable {
    var urlsToDrag: () -> [URL]
    var dragImage: () -> NSImage?
    var onClick: () -> Void

    func makeNSView(context: Context) -> DragSelectionNSView {
        let view = DragSelectionNSView()
        apply(to: view)
        return view
    }

    func updateNSView(_ view: DragSelectionNSView, context: Context) {
        apply(to: view)
    }

    private func apply(to view: DragSelectionNSView) {
        view.urlsToDrag = urlsToDrag
        view.dragImage = dragImage
        view.onClick = onClick
    }
}

final class DragSelectionNSView: NSView, NSDraggingSource {
    var urlsToDrag: (() -> [URL])?
    var dragImage: (() -> NSImage?)?
    var onClick: (() -> Void)?

    private var mouseDownPoint: NSPoint?
    private var didStartDrag = false
    private var trackingArea: NSTrackingArea?

    private let dragThreshold: CGFloat = 4
    private let stackOffset: CGFloat = 6

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // Подсветка наведения рисуется прямо в слое. Через SwiftUI это стоило
        // бы пересборки ячейки вместе с этим самым NSView на каждое движение
        // мыши между миниатюрами.
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    // Окно шторки никогда не активно, поэтому первый клик нужно принимать явно.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.16).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = .clear
    }

    /// Контекстное меню объявлено в SwiftUI, а правый клик приходит сюда —
    /// пробрасываем запрос выше по иерархии.
    override func menu(for event: NSEvent) -> NSMenu? {
        superview?.menu(for: event) ?? super.menu(for: event)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = event.locationInWindow
        didStartDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint, !didStartDrag else { return }
        let distance = hypot(
            event.locationInWindow.x - start.x,
            event.locationInWindow.y - start.y
        )
        guard distance > dragThreshold else { return }
        didStartDrag = true
        beginDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownPoint = nil
            didStartDrag = false
        }
        guard !didStartDrag else { return }
        onClick?()
    }

    private func beginDrag(with event: NSEvent) {
        let urls = urlsToDrag?() ?? []
        guard !urls.isEmpty else { return }
        let image = dragImage?()

        // Стопка со смещением — видно, что тянется несколько файлов.
        let items = urls.enumerated().map { index, url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let shift = CGFloat(index) * stackOffset
            item.setDraggingFrame(
                NSRect(x: shift, y: -shift, width: bounds.width, height: bounds.height),
                contents: image
            )
            return item
        }

        beginDraggingSession(with: items, event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }
}
