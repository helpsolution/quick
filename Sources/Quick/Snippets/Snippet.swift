import AppKit

/// Заготовка — кусок текста, который иначе пришлось бы набирать руками.
/// Ни имени, ни ярлыка: команду узнают по ней самой, а второе поле пришлось бы
/// придумывать при каждом добавлении.
struct Snippet: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }

    /// В ленте помещается одна строка, поэтому многострочную заготовку
    /// показываем первой строкой и отмечаем, что она не вся.
    var previewLine: String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first else { return "" }
        let head = String(first)
        return lines.count > 1 ? head + " …" : head
    }

    var isBlank: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Размеры ленты заготовок. Держим рядом с моделью, а не в [PanelLayout]:
/// ширина строки считается по фактическому тексту и требует AppKit.
enum SnippetLayout {
    static let rowHeight: CGFloat = 24
    static let rowSpacing: CGFloat = 2
    /// Отступ текста внутри строки — с обеих сторон.
    static let rowInset: CGFloat = 8
    static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    /// Карточка повторяет размер миниатюры скриншота — иначе два раздела
    /// сравнивать не с чем.
    static let cardSize = PanelLayout.thumbnail
    static let cardSpacing = PanelLayout.spacing
    static let cardFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

    /// Ширина, при которой самая длинная заготовка помещается целиком.
    /// Больше `PanelLayout.maxWidth` панель всё равно не станет — там текст
    /// уедет в многоточие, и это честнее, чем шторка во весь экран.
    static func rowsContentWidth(for items: [Snippet]) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let widest = items.reduce(CGFloat.zero) { widest, snippet in
            max(widest, (snippet.previewLine as NSString).size(withAttributes: attributes).width)
        }
        return widest.rounded(.up) + rowInset * 2
    }

    static func cardsContentWidth(for items: [Snippet]) -> CGFloat {
        guard !items.isEmpty else { return 0 }
        return CGFloat(items.count) * cardSize.width
            + CGFloat(items.count - 1) * cardSpacing
    }

    static func contentWidth(for items: [Snippet], asCards: Bool) -> CGFloat {
        asCards ? cardsContentWidth(for: items) : rowsContentWidth(for: items)
    }
}
