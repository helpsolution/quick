import Foundation

/// Список заготовок и его файл на диске.
///
/// Порядок задаёт пользователь и он же — порядок в ленте: то, чем пользуешься
/// каждый день, поднимается наверх руками. Сортировать по частоте автоматически
/// нельзя — лента бы перетасовывалась под курсором.
@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var items: [Snippet] = []

    /// Запись отложенная: редактор дёргает `update` на каждое нажатие клавиши,
    /// а файл того не стоит.
    private static let saveDelay: TimeInterval = 0.6
    private var saveScheduled = false

    private static let queue = DispatchQueue(label: "co.quick.snippets", qos: .utility)

    private nonisolated static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Quick/snippets.json")
    }

    func start() {
        Self.queue.async {
            let loaded = Self.load()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Пользователь мог успеть что-то добавить, пока крутился диск:
                // свой список в этом случае важнее прочитанного.
                guard self.items.isEmpty else { return }
                self.items = loaded
            }
        }
    }

    // MARK: - Правка

    @discardableResult
    func add(text: String = "") -> Snippet {
        let snippet = Snippet(text: text)
        items.append(snippet)
        scheduleSave()
        return snippet
    }

    func update(id: Snippet.ID, text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].text != text else { return }
        items[index].text = text
        scheduleSave()
    }

    func remove(ids: Set<Snippet.ID>) {
        guard !ids.isEmpty else { return }
        items.removeAll { ids.contains($0.id) }
        scheduleSave()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        scheduleSave()
    }

    /// Пустые заготовки в ленте только занимают место: добавленная и брошенная
    /// строка не должна пережить закрытие редактора.
    func dropBlanks() {
        let cleaned = items.filter { !$0.isBlank }
        guard cleaned.count != items.count else { return }
        items = cleaned
        scheduleSave()
    }

    // MARK: - Файл

    private func scheduleSave() {
        guard !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.saveDelay) { [weak self] in
            self?.saveNow()
        }
    }

    private func saveNow() {
        saveScheduled = false
        let snapshot = items.filter { !$0.isBlank }
        Self.queue.async { Self.write(snapshot) }
    }

    private nonisolated static func load() -> [Snippet] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Snippet].self, from: data)) ?? []
    }

    private nonisolated static func write(_ items: [Snippet]) {
        let url = fileURL
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(items)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Quick: не удалось сохранить заготовки — \(error.localizedDescription)")
        }
    }
}
