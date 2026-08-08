import AppKit

enum FileActions {
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func openFolder(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// В корзину, а не rm — пользователь должен иметь возможность откатить.
    static func moveToTrash(_ url: URL) {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}
