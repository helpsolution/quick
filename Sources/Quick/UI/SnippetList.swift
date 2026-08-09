import SwiftUI

/// Лента заготовок в шторке — только чтение. Править здесь нечего: окно шторки
/// не может стать ключевым (см. [PassiveWindow]) и закрывается, стоит увести
/// курсор, — редактор живёт отдельным окном.
///
/// Два вида под сравнение: строками, где команда видна целиком, и карточками
/// в размер миниатюры скриншота. Какой останется — покажет привычка.
struct SnippetList: View {
    @ObservedObject var store: SnippetStore
    let asCards: Bool
    let onUse: (Snippet, Int) -> Void
    let onEdit: () -> Void

    var body: some View {
        if store.items.isEmpty {
            empty
        } else if asCards {
            cards
        } else {
            rows
        }
    }

    private var rows: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: SnippetLayout.rowSpacing) {
                ForEach(Array(store.items.enumerated()), id: \.element.id) { index, snippet in
                    SnippetRow(snippet: snippet) { onUse(snippet, index) }
                }
            }
        }
        .frame(height: PanelLayout.thumbnail.height)
    }

    private var cards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SnippetLayout.cardSpacing) {
                ForEach(Array(store.items.enumerated()), id: \.element.id) { index, snippet in
                    SnippetCard(snippet: snippet) { onUse(snippet, index) }
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: PanelLayout.thumbnail.height)
    }

    private var empty: some View {
        HStack(spacing: 10) {
            Text("Заготовок пока нет")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            Button("Добавить…", action: onEdit)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: PanelLayout.thumbnail.height)
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let onUse: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Text(snippet.previewLine)
                .font(Font(SnippetLayout.font))
                .foregroundStyle(.white.opacity(isHovered ? 0.95 : 0.75))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SnippetLayout.rowInset)
        .frame(height: SnippetLayout.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.white.opacity(isHovered ? 0.1 : 0.05))
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onUse)
        .help(snippet.text)
    }
}

/// Карточка в размер миниатюры. Текст переносится и обрезается снизу: на
/// 120 × 78 целиком помещается разве что короткая команда — в этом и вопрос,
/// который вид карточек должен помочь решить.
private struct SnippetCard: View {
    let snippet: Snippet
    let onUse: () -> Void

    @State private var isHovered = false

    var body: some View {
        Text(snippet.text)
            .font(Font(SnippetLayout.cardFont))
            .foregroundStyle(.white.opacity(isHovered ? 0.95 : 0.78))
            .lineLimit(4)
            .truncationMode(.tail)
            .multilineTextAlignment(.leading)
            .frame(
                width: SnippetLayout.cardSize.width - 16,
                height: SnippetLayout.cardSize.height - 16,
                alignment: .topLeading
            )
            .padding(8)
            .frame(width: SnippetLayout.cardSize.width, height: SnippetLayout.cardSize.height)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(isHovered ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture(perform: onUse)
            .help(snippet.text)
    }
}
