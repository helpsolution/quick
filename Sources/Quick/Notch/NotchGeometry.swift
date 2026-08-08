import AppKit

/// Геометрия челки (или её отсутствия) на конкретном экране.
struct NotchGeometry {
    let screen: NSScreen
    let hasNotch: Bool
    /// Зона наведения в глобальных координатах экрана.
    let hoverRect: CGRect

    static let fallbackWidth: CGFloat = 180

    static func current() -> NotchGeometry? {
        guard let screen = NSScreen.screens.first(where: { $0.notchWidth != nil }) ?? NSScreen.main else { return nil }

        let frame = screen.frame
        let hasNotch = screen.notchWidth != nil
        let width = screen.notchWidth ?? fallbackWidth
        let height = screen.topInsetHeight

        let hoverRect = CGRect(
            x: frame.midX - width / 2,
            y: frame.maxY - height,
            width: width,
            height: height
        )
        return NotchGeometry(screen: screen, hasNotch: hasNotch, hoverRect: hoverRect)
    }

    /// Толщина полосы у верхней кромки, в которой шторка срабатывает.
    /// Вся высота челки не годится: по строке меню курсор ходит постоянно,
    /// и шторка выскакивала бы посреди обычной работы.
    static let edgeThickness: CGFloat = 3

    /// Зона срабатывания: курсор должен упереться в самый верх экрана в пределах
    /// челки. Прямоугольник на пиксель выше кромки — `contains` не считает
    /// верхнюю границу своей, а у края экрана курсор лежит ровно на ней.
    var triggerRect: CGRect {
        CGRect(
            x: hoverRect.minX,
            y: hoverRect.maxY - Self.edgeThickness,
            width: hoverRect.width,
            height: Self.edgeThickness + 1
        )
    }

    /// Кадр окна панели: от верха экрана вниз, по центру челки.
    func panelWindowFrame(width: CGFloat, panelHeight: CGFloat) -> CGRect {
        let frame = screen.frame
        let totalHeight = hoverRect.height + panelHeight + PanelLayout.edgePadding
        return CGRect(
            x: (frame.midX - width / 2).rounded(),
            y: frame.maxY - totalHeight,
            width: width,
            height: totalHeight
        )
    }
}

extension NSScreen {
    /// Ширина физического выреза. nil, если экран без челки.
    var notchWidth: CGFloat? {
        guard let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea else { return nil }
        let width = frame.width - left.width - right.width
        return width > 1 ? width : nil
    }

    /// Высота челки, а на экранах без неё — высота строки меню.
    var topInsetHeight: CGFloat {
        let inset = safeAreaInsets.top
        if inset > 1 { return inset }
        let menuBar = frame.maxY - visibleFrame.maxY
        return menuBar > 1 ? menuBar : NSStatusBar.system.thickness
    }
}
