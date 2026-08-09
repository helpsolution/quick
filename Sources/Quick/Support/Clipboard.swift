import AppKit

enum Clipboard {
    /// Провайдеры обязаны пережить саму операцию копирования: данные у них
    /// запрашивают позже, в момент вставки.
    private static var liveProviders: [ScreenshotDataProvider] = []

    /// Каждый скриншот кладётся в двух представлениях: PNG (вставится картинкой
    /// в редактор или мессенджер) и file URL (вставится файлом в Finder).
    /// Несколько элементов — несколько items: Finder и мессенджеры вставят все,
    /// однокартиночные приёмники возьмут первый.
    ///
    /// PNG отдаётся лениво. Иначе каждый клик при множественном выборе
    /// перечитывал бы с диска все выбранные файлы целиком — на десятки
    /// мегабайт за клик.
    @discardableResult
    static func copy(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }

        var providers: [ScreenshotDataProvider] = []
        let items = urls.map { url -> NSPasteboardItem in
            let item = NSPasteboardItem()
            let provider = ScreenshotDataProvider(url: url)
            providers.append(provider)
            item.setDataProvider(provider, forTypes: [.png])
            item.setData((url as NSURL).dataRepresentation, forType: .fileURL)
            return item
        }
        liveProviders = providers

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects(items)
    }

    @discardableResult
    static func copy(_ url: URL) -> Bool {
        copy([url])
    }

    /// Текст заготовки. Провайдеры прошлого копирования отпускаем: держать
    /// открытыми файлы, которые уже никто не попросит, незачем.
    @discardableResult
    static func copy(text: String) -> Bool {
        liveProviders = []
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    static func pngData(for url: URL) -> Data? {
        if url.pathExtension.lowercased() == "png" {
            return try? Data(contentsOf: url)
        }
        guard let image = NSImage(contentsOf: url),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

/// Читает файл только когда приёмник вставки действительно просит картинку.
final class ScreenshotDataProvider: NSObject, NSPasteboardItemDataProvider {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func pasteboard(
        _ pasteboard: NSPasteboard?,
        item: NSPasteboardItem,
        provideDataForType type: NSPasteboard.PasteboardType
    ) {
        guard type == .png, let data = Clipboard.pngData(for: url) else { return }
        item.setData(data, forType: .png)
    }
}
