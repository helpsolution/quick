import AppKit
import Combine
import SwiftUI

/// Связывает чёлку, окно панели и хранилище скриншотов.
@MainActor
final class NotchController {
    private let store: ScreenshotStore
    private let state = PanelState()
    private let selection = SelectionStore()
    private lazy var settingsWindow = SettingsWindowController()

    private var geometry: NotchGeometry?
    private var hoverWindow: PassiveWindow?
    private var panelWindow: PassiveWindow?

    private var isOpen = false
    private var closeWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private var mouseMonitor: Any?

    private let closeDelay: TimeInterval = 0.22
    private let hideAnimationDuration: TimeInterval = 0.35

    init(store: ScreenshotStore) {
        self.store = store
    }

    func start() {
        rebuild()
        startMouseMonitor()

        store.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                guard let self else { return }
                self.state.panelWidth = PanelLayout.width(for: items.count)
                // Обновляем и когда закрыто — иначе первое открытие после
                // запуска показывает панель прежней ширины.
                self.updatePanelFrame()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)
    }

    // MARK: - Отслеживание курсора

    /// Tracking area привязана к окну, а в чужом полноэкранном Space окно до
    /// курсора не достаёт. Глобальный монитор движений мыши работает везде и
    /// не требует разрешений (в отличие от слежения за клавиатурой).
    private func startMouseMonitor() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleGlobalMouseMove() }
        }
    }

    private func handleGlobalMouseMove() {
        guard let geometry else { return }
        let mouse = NSEvent.mouseLocation

        if geometry.triggerRect.contains(mouse) {
            if isOpen {
                closeWork?.cancel()
                closeWork = nil
            } else {
                handleEnter()
            }
            return
        }

        guard isOpen, closeWork == nil else { return }
        if isMouseOverPanel(mouse) { return }
        handleExit()
    }

    /// Курсор у верхнего края экрана лежит ровно на границе кадра, а `contains`
    /// верхнюю границу своей не считает — поэтому кадр расширяется на пиксель.
    private func isMouseOverPanel(_ mouse: CGPoint) -> Bool {
        guard let panelWindow else { return false }
        return panelWindow.frame.insetBy(dx: 0, dy: -1).contains(mouse)
    }

    // MARK: - Окна

    private func rebuild() {
        guard let geometry = NotchGeometry.current() else { return }
        self.geometry = geometry
        state.notchHeight = geometry.hoverRect.height
        state.panelWidth = PanelLayout.width(for: store.items.count)

        if let hoverWindow {
            hoverWindow.setFrame(geometry.hoverRect, display: false)
        } else {
            hoverWindow = makeHoverWindow(frame: geometry.hoverRect)
        }
        hoverWindow?.orderFrontRegardless()

        if panelWindow == nil {
            panelWindow = makePanelWindow()
        }
        updatePanelFrame()
    }

    private func makeHoverWindow(frame: CGRect) -> PassiveWindow {
        let window = PassiveWindow(contentRect: frame)
        let tracking = HoverTrackingView(frame: CGRect(origin: .zero, size: frame.size))
        tracking.onEnter = { [weak self] in self?.handleEnter() }
        tracking.onExit = { [weak self] in self?.handleExit() }
        window.contentView = tracking
        window.setFrame(frame, display: false)
        return window
    }

    private func makePanelWindow() -> PassiveWindow {
        let window = PassiveWindow(contentRect: CGRect(x: 0, y: 0, width: 100, height: 100))

        let root = NotchPanelView(
            store: store,
            state: state,
            selection: selection,
            onClick: { [weak self] screenshot, index in self?.handleClick(screenshot, at: index) },
            onCopyOnly: { [weak self] screenshot in self?.copyOnly(screenshot) },
            onOpenSettings: { [weak self] in self?.settingsWindow.show() }
        )
        let hosting = FirstMouseHostingView(rootView: root)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let container = HoverTrackingView(frame: .zero)
        container.onEnter = { [weak self] in self?.handleEnter() }
        container.onExit = { [weak self] in self?.handleExit() }
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        window.contentView = container
        // Панель всегда тёмная, поэтому и оформление окна закрепляем тёмным.
        // Иначе системные контролы внутри (кнопка меню «…», сами пункты меню)
        // следуют за оформлением системы и днём становятся тёмными на тёмном.
        window.appearance = NSAppearance(named: .darkAqua)
        // Пока шторка закрыта, окно не должно ни рисоваться, ни перехватывать
        // клики по строке меню — orderOut одного мало, SwiftUI-хостинг умеет
        // вернуть окно на экран сам.
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.orderOut(nil)
        return window
    }

    private func updatePanelFrame() {
        guard let geometry, let panelWindow else { return }
        let windowWidth = state.panelWidth + PanelLayout.edgePadding * 2
        let frame = geometry.panelWindowFrame(width: windowWidth, panelHeight: PanelLayout.height)
        panelWindow.setFrame(frame, display: isOpen)
    }

    // MARK: - Открытие и закрытие

    /// Открывать только когда курсор действительно в чёлке, кто бы ни прислал
    /// событие. Окно панели накрывает верхние ~190 pt экрана, и его tracking
    /// area срабатывает даже после того, как окно убрано с экрана, — иначе
    /// шторка выезжала бы на подходе к чёлке, а не по достижении.
    private func handleEnter() {
        if isOpen {
            closeWork?.cancel()
            closeWork = nil
            return
        }
        guard let geometry, geometry.triggerRect.contains(NSEvent.mouseLocation) else { return }
        closeWork?.cancel()
        closeWork = nil
        open()
    }

    private func handleExit() {
        guard closeWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in self?.closeIfMouseOutside() }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + closeDelay, execute: work)
    }

    private func open() {
        guard !isOpen else { return }
        isOpen = true
        store.refreshFolderIfNeeded()
        updatePanelFrame()
        panelWindow?.ignoresMouseEvents = false
        panelWindow?.alphaValue = 1
        panelWindow?.orderFrontRegardless()
        state.isExpanded = true
        EventLog.shared.panelOpened()
    }

    private func closeIfMouseOutside() {
        closeWork = nil
        let mouse = NSEvent.mouseLocation
        if let geometry, geometry.triggerRect.contains(mouse) { return }
        if isOpen, isMouseOverPanel(mouse) { return }
        close()
    }

    private func close() {
        guard isOpen else { return }
        isOpen = false
        state.isExpanded = false
        selection.clear()
        EventLog.shared.panelClosed()
        panelWindow?.ignoresMouseEvents = true

        DispatchQueue.main.asyncAfter(deadline: .now() + hideAnimationDuration) { [weak self] in
            guard let self, !self.isOpen else { return }
            self.panelWindow?.alphaValue = 0
            self.panelWindow?.orderOut(nil)
        }
    }

    // MARK: - Действия

    /// Привычная для macOS раскладка: ⌘-клик переключает отдельный скриншот,
    /// Shift-клик берёт диапазон от последнего выбранного, обычный клик
    /// заменяет выбор целиком. Буфер обновляется на каждом клике, поэтому
    /// после выбора ничего дополнительно нажимать не нужно.
    private func handleClick(_ screenshot: Screenshot, at index: Int) {
        let items = store.items
        let flags = NSEvent.modifierFlags

        if flags.contains(.shift), let anchor = selection.anchorIndex, items.indices.contains(anchor) {
            let range = min(anchor, index)...max(anchor, index)
            selection.replace(with: Set(items[range].map(\.id)))
        } else if flags.contains(.command) {
            selection.toggle(screenshot.id)
            selection.anchorIndex = index
        } else {
            selection.replace(with: [screenshot.id])
            selection.anchorIndex = index
        }

        copySelection(clickedAt: index)
    }

    private func copyOnly(_ screenshot: Screenshot) {
        let index = store.items.firstIndex { $0.id == screenshot.id }
        selection.replace(with: [screenshot.id])
        selection.anchorIndex = index
        copySelection(clickedAt: index)
    }

    private func selectedInScreenOrder() -> [URL] {
        store.items.filter { selection.contains($0.id) }.map(\.url)
    }

    /// Порядок в буфере — как на экране, а не как в множестве выбранных.
    private func copySelection(clickedAt index: Int?) {
        let urls = selectedInScreenOrder()
        guard !urls.isEmpty else {
            // Снятие выбора ⌘-кликом — не копирование, считать нечего.
            NSPasteboard.general.clearContents()
            return
        }
        Clipboard.copy(urls)
        EventLog.shared.copied(count: urls.count, index: index)
    }
}
