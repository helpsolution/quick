import Foundation

/// Состояние самой шторки. Меняется редко — на открытии, закрытии и смене
/// экрана. Выбор скриншотов сюда не входит: см. [SelectionStore].
@MainActor
final class PanelState: ObservableObject {
    @Published var isExpanded = false
    @Published var panelWidth: CGFloat = PanelLayout.minWidth
    @Published var notchHeight: CGFloat = 32
}
