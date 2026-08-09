import Foundation

/// Разделы шторки. Вкладка помнится между показами: у того, кто пришёл за
/// заготовками, шторка не должна каждый раз открываться на скриншотах.
enum PanelTab: Hashable {
    case screenshots
    case snippets
}

/// Состояние самой шторки. Меняется редко — на открытии, закрытии и смене
/// экрана. Выбор скриншотов сюда не входит: см. [SelectionStore].
@MainActor
final class PanelState: ObservableObject {
    @Published var isExpanded = false
    @Published var panelWidth: CGFloat = PanelLayout.minWidth
    @Published var notchHeight: CGFloat = 32
    @Published var tab: PanelTab = .screenshots
    @Published var snippetsEnabled = Experiments.snippetsEnabled
    @Published var snippetsAsCards = Experiments.snippetsAsCards
    /// Есть ли доступ к «Универсальному доступу». Проверяется на открытии
    /// шторки, а не в `body`: вызов ходит за пределы процесса.
    @Published var pasteAllowed = Paster.isTrusted
}
