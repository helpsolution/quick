import Foundation

/// Выбор живёт отдельно от остального состояния панели намеренно.
///
/// Наблюдатель SwiftUI инвалидируется на любое изменение объекта, а не только
/// того свойства, которое читал. Пока выбор лежал в `PanelState`, каждый клик
/// перестраивал всю панель вместе с AppKit-слоями ячеек — 26 мс процессорного
/// времени на клик против 4 мс без них. Теперь клик трогает только те вьюхи,
/// которые показывают отметку выбора.
@MainActor
final class SelectionStore: ObservableObject {
    @Published private(set) var ids: Set<String> = []

    /// Точка отсчёта для выбора диапазона по Shift.
    var anchorIndex: Int?

    var count: Int { ids.count }
    var isEmpty: Bool { ids.isEmpty }

    func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    func replace(with newIDs: Set<String>) {
        ids = newIDs
    }

    func toggle(_ id: String) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
    }

    func clear() {
        ids = []
        anchorIndex = nil
    }
}
