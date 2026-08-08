import AVFoundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

// Превращает запись экрана в гифку для README.
// Запуск: swift scripts/make-gif.swift <видео.mov> [ширина] [кадров в секунду]
//
// ffmpeg не нужен: кадры достаёт AVFoundation, собирает в гифку ImageIO.

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    print("нужен путь к видео: swift scripts/make-gif.swift запись.mov [ширина] [fps]")
    exit(1)
}

let input = URL(fileURLWithPath: arguments[1])
let targetWidth = CGFloat(arguments.count > 2 ? Double(arguments[2]) ?? 800 : 800)
let fps = Double(arguments.count > 3 ? Double(arguments[3]) ?? 12 : 12)
let output = input.deletingPathExtension().appendingPathExtension("gif")

let asset = AVURLAsset(url: input)
let duration = try await CMTimeGetSeconds(asset.load(.duration))
guard duration > 0 else {
    print("не удалось прочитать видео")
    exit(1)
}

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
generator.maximumSize = CGSize(width: targetWidth * 2, height: 0)

let frameCount = Int(duration * fps)
let delay = 1.0 / fps

guard let destination = CGImageDestinationCreateWithURL(
    output as CFURL, UTType.gif.identifier as CFString, frameCount, nil
) else {
    print("не удалось создать файл гифки")
    exit(1)
}

CGImageDestinationSetProperties(destination, [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
] as CFDictionary)

let frameProperties = [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]
] as CFDictionary

var written = 0
for index in 0..<frameCount {
    let time = CMTime(seconds: Double(index) / fps, preferredTimescale: 600)
    guard let frame = try? await generator.image(at: time).image else { continue }

    // Масштабируем до целевой ширины: гифка для README не должна весить мегабайты.
    let scale = targetWidth / CGFloat(frame.width)
    let width = Int(targetWidth)
    let height = Int(CGFloat(frame.height) * scale)

    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { continue }
    context.interpolationQuality = .high
    context.draw(frame, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let scaled = context.makeImage() else { continue }
    CGImageDestinationAddImage(destination, scaled, frameProperties)
    written += 1
}

guard CGImageDestinationFinalize(destination), written > 0 else {
    print("не удалось собрать гифку")
    exit(1)
}

let size = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
print("готово: \(output.path)")
print("кадров: \(written), длительность: \(String(format: "%.1f", duration)) с, размер: \(size / 1024) КБ")
if size > 3_000_000 {
    print("великовато для README — уменьшите ширину или частоту кадров")
}
