import SwiftUI

/// Редактор заготовок. Живёт отдельным окном, а не в шторке: ввод текста
/// требует фокуса, а шторка его не берёт и закрывается по уходу курсора.
struct SnippetsEditorView: View {
    @ObservedObject var store: SnippetStore
    @State private var selection: Set<Snippet.ID> = []

    static let windowSize = CGSize(width: 620, height: 380)

    var body: some View {
        HSplitView {
            list
                .frame(minWidth: 220, idealWidth: 240, maxWidth: 320)
            editor
                .frame(minWidth: 260)
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .onDisappear { store.dropBlanks() }
    }

    // MARK: - Список

    private var list: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(store.items) { snippet in
                    Text(snippet.previewLine.isEmpty ? "Новая заготовка" : snippet.previewLine)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(snippet.isBlank ? .secondary : .primary)
                        .lineLimit(1)
                        .tag(snippet.id)
                }
                .onMove { store.move(from: $0, to: $1) }
            }
            .listStyle(.inset)

            Divider()

            HStack(spacing: 0) {
                listButton("plus", help: "Добавить заготовку") {
                    let added = store.add()
                    selection = [added.id]
                }
                listButton("minus", help: "Удалить выбранные") {
                    store.remove(ids: selection)
                    selection = []
                }
                .disabled(selection.isEmpty)

                Spacer()

                Text("Порядок меняется перетаскиванием")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 8)
            }
            .frame(height: 26)
        }
    }

    private func listButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    // MARK: - Правка

    @ViewBuilder
    private var editor: some View {
        if let id = singleSelection {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: binding(for: id))
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )

                Text("Клик по заготовке в шторке копирует ее и вставляет в активное приложение.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        } else {
            Text(selection.isEmpty ? "Выберите заготовку слева" : "Выбрано несколько заготовок")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var singleSelection: Snippet.ID? {
        selection.count == 1 ? selection.first : nil
    }

    /// Правка идёт прямо в хранилище: отдельная копия текста в `@State`
    /// разъезжалась бы со списком слева на каждом переключении выбора.
    private func binding(for id: Snippet.ID) -> Binding<String> {
        Binding(
            get: { store.items.first { $0.id == id }?.text ?? "" },
            set: { store.update(id: id, text: $0) }
        )
    }
}
