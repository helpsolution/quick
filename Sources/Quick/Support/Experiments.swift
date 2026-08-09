import Foundation

/// Разделы шторки, которые ещё не прижились. Живут за своим ключом и включены
/// по умолчанию: эксперимент, до которого никто не добрался в настройках,
/// ничего не проверяет. Выключенный эксперимент возвращает шторку ровно в то
/// состояние, в котором она была до него.
enum Experiments {
    static let snippetsKey = "SnippetsEnabled"
    static let snippetsCardsKey = "SnippetsAsCards"

    static var snippetsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: snippetsKey) }
        set { UserDefaults.standard.set(newValue, forKey: snippetsKey) }
    }

    /// Карточками — как миниатюры скриншотов, — или строками списка.
    static var snippetsAsCards: Bool {
        get { UserDefaults.standard.bool(forKey: snippetsCardsKey) }
        set { UserDefaults.standard.set(newValue, forKey: snippetsCardsKey) }
    }

    /// Вызывать до создания шторки: она читает флаги при сборке состояния.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            snippetsKey: true,
            snippetsCardsKey: true
        ])
    }
}
