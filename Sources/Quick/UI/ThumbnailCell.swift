import SwiftUI

/// Ячейка намеренно не читает выбор и не хранит состояние наведения: всё, что
/// меняется от кликов и мыши, вынесено в [SelectionMark] и в AppKit-слой.
/// Иначе каждый клик пересобирал бы вместе с ячейкой и её `NSViewRepresentable`.
struct ThumbnailCell: View {
    let screenshot: Screenshot
    let selection: SelectionStore
    /// Считается в момент начала перетаскивания и по ссылке на состояние —
    /// снимок, захваченный при создании ячейки, к тому времени уже устаревает.
    let dragURLs: () -> [URL]
    let onClick: () -> Void
    let onCopyOnly: () -> Void

    var body: some View {
        ZStack {
            ThumbnailImage(screenshot: screenshot)
                .frame(width: PanelLayout.thumbnail.width, height: PanelLayout.thumbnail.height)
                .clipped()

            SelectionMark(selection: selection, id: screenshot.id)
        }
        .frame(width: PanelLayout.thumbnail.width, height: PanelLayout.thumbnail.height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
                DragSelectionView(
                    urlsToDrag: dragURLs,
                    dragImage: { ThumbnailCache.shared.cached(for: screenshot, maxPixel: PanelLayout.thumbnailMaxPixel) },
                    onClick: onClick
                )
            )
            .contentShape(Rectangle())
            .contextMenu {
                Button("Скопировать только этот") { onCopyOnly() }
                Button("Открыть") { FileActions.open(screenshot.url) }
                Button("Показать в Finder") { FileActions.revealInFinder(screenshot.url) }
                Divider()
                Button("Переместить в корзину", role: .destructive) {
                    FileActions.moveToTrash(screenshot.url)
                }
            }
            .help("\(screenshot.url.lastPathComponent) — \(Self.stamp(screenshot.modified))")
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "d MMM, HH:mm"
        }
        return formatter.string(from: date)
    }
}

/// Единственное, что перерисовывается при клике: рамка и галочка.
private struct SelectionMark: View {
    @ObservedObject var selection: SelectionStore
    let id: String

    var body: some View {
        let isSelected = selection.contains(id)
        ZStack {
            if isSelected {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(5)
                    }
                    Spacer()
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : .white.opacity(0.1),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .allowsHitTesting(false)
    }
}

private struct ThumbnailImage: View {
    let screenshot: Screenshot
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.white.opacity(0.06)
            }
        }
        .task(id: screenshot.id) {
            if let cached = ThumbnailCache.shared.cached(for: screenshot, maxPixel: PanelLayout.thumbnailMaxPixel) {
                image = cached
                return
            }
            image = await ThumbnailCache.shared.thumbnail(for: screenshot, maxPixel: PanelLayout.thumbnailMaxPixel)
        }
    }
}
