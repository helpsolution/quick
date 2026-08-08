import AppKit
import Combine

struct Screenshot: Identifiable, Equatable {
    let url: URL
    let modified: Date
    let size: Int

    var id: String { url.path + "|" + String(Int(modified.timeIntervalSince1970)) }
}

@MainActor
final class ScreenshotStore: ObservableObject {
    @Published private(set) var items: [Screenshot] = []
    /// macOS не дал прочитать папку — нужно выдать доступ в Настройках.
    @Published private(set) var accessDenied = false
    @Published private(set) var folder: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop", isDirectory: true)

    private let limit: Int
    private var watcher: FolderWatcher?
    private var isReloading = false
    private var reloadQueued = false
    private var isResolvingFolder = false

    init(limit: Int = 40) {
        self.limit = limit
    }

    func start() {
        resolveFolder()
    }

    /// Папку скриншотов могли поменять в системных настройках, пока приложение работало.
    /// Проверка ходит на диск, поэтому выполняется вне главного потока.
    func refreshFolderIfNeeded() {
        resolveFolder()
    }

    private func resolveFolder() {
        guard !isResolvingFolder else { return }
        isResolvingFolder = true

        Task.detached(priority: .utility) {
            let resolved = ScreenshotFolder.current()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isResolvingFolder = false
                if resolved != self.folder || self.watcher == nil {
                    self.folder = resolved
                    self.rebindWatcher()
                }
                self.reload()
            }
        }
    }

    private func rebindWatcher() {
        watcher?.stop()
        watcher = FolderWatcher(url: folder) { [weak self] in self?.reload() }
        watcher?.start()
    }

    func reload() {
        guard !isReloading else {
            reloadQueued = true
            return
        }
        isReloading = true

        let folder = self.folder
        let limit = self.limit

        Task.detached(priority: .userInitiated) {
            let result = Self.scan(folder: folder, limit: limit)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.items = result.items
                self.accessDenied = result.accessDenied
                self.isReloading = false
                if self.reloadQueued {
                    self.reloadQueued = false
                    self.reload()
                }
            }
        }
    }

    private nonisolated static func scan(folder: URL, limit: Int) -> (items: [Screenshot], accessDenied: Bool) {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
        } catch {
            let denied = (error as NSError).code == NSFileReadNoPermissionError
            return ([], denied)
        }

        let screenshots: [Screenshot] = contents.compactMap { url in
            guard ScreenshotFolder.imageExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate
            else { return nil }
            return Screenshot(url: url, modified: modified, size: values.fileSize ?? 0)
        }

        let sorted = screenshots.sorted { $0.modified > $1.modified }
        return (Array(sorted.prefix(limit)), false)
    }
}
