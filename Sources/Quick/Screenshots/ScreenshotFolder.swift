import Foundation

/// Определяет, куда macOS складывает скриншоты.
enum ScreenshotFolder {
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "gif", "tiff", "tif", "webp"]

    /// Путь из `defaults read com.apple.screencapture location`, иначе — Рабочий стол.
    static func current() -> URL {
        if let raw = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !raw.isEmpty {
            let expanded = (raw as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue {
                return URL(fileURLWithPath: expanded, isDirectory: true)
            }
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }
}
