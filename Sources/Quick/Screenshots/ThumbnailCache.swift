import AppKit
import ImageIO

/// Миниатюры через ImageIO downsampling — заметно быстрее Quick Look
/// (нет XPC-раунда) и не тянет полное изображение в память.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 120
        return cache
    }()
    private var inFlight: [String: Task<NSImage?, Never>] = [:]

    func cached(for screenshot: Screenshot, maxPixel: CGFloat) -> NSImage? {
        cache.object(forKey: key(screenshot, maxPixel) as NSString)
    }

    func thumbnail(for screenshot: Screenshot, maxPixel: CGFloat) async -> NSImage? {
        let key = key(screenshot, maxPixel)
        if let hit = cache.object(forKey: key as NSString) { return hit }
        if let running = inFlight[key] { return await running.value }

        let url = screenshot.url
        let task = Task<NSImage?, Never>.detached(priority: .userInitiated) {
            Self.downsample(url: url, maxPixel: maxPixel)
        }
        inFlight[key] = task

        let image = await task.value
        inFlight[key] = nil
        if let image { cache.setObject(image, forKey: key as NSString) }
        return image
    }

    private func key(_ screenshot: Screenshot, _ maxPixel: CGFloat) -> String {
        "\(screenshot.url.path)|\(Int(screenshot.modified.timeIntervalSince1970))|\(Int(maxPixel))"
    }

    private nonisolated static func downsample(url: URL, maxPixel: CGFloat) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
