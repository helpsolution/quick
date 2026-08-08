import CoreGraphics

enum PanelLayout {
    static let thumbnail = CGSize(width: 120, height: 78)
    static let spacing: CGFloat = 10
    static let padding: CGFloat = 14
    static let headerHeight: CGFloat = 18
    static let headerGap: CGFloat = 8
    static let cornerRadius: CGFloat = 20
    /// Запас вокруг панели: окно чуть больше её самой, чтобы курсор не терял
    /// шторку на самой границе.
    static let edgePadding: CGFloat = 24
    static let minWidth: CGFloat = 340
    static let maxWidth: CGFloat = 760
    static let thumbnailMaxPixel: CGFloat = 320

    static var height: CGFloat {
        padding + headerHeight + headerGap + thumbnail.height + padding
    }

    static func width(for count: Int) -> CGFloat {
        let visible = max(count, 1)
        let content = CGFloat(visible) * thumbnail.width
            + CGFloat(visible - 1) * spacing
            + padding * 2
        return min(max(content, minWidth), maxWidth)
    }
}
