import AppKit

// Иконка приложения: шторка, из которой берут готовый артефакт.
// Запуск: swift scripts/make-icon.swift  → Resources/AppIcon.icns
//
// Правки держать здесь: иконка не лежит в репозитории картинкой, а рисуется
// кодом, поэтому меняются числа, а не пиксели.

let bodyTop = NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.19, alpha: 1)
let bodyBottom = NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.07, alpha: 1)
/// Шторка — то, что уже лежит под рукой.
let panelColor = NSColor.white
/// Артефакт, который забирают. Светлее середины, иначе тонет в тёмном корпусе.
let itemColor = NSColor(calibratedWhite: 0.72, alpha: 1)

func body(_ size: CGFloat) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    ctx.saveGState()
    let r = size * 0.2237
    NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), xRadius: r, yRadius: r).addClip()
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: [bodyTop.cgColor, bodyBottom.cgColor] as CFArray,
                                 locations: [0, 1]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
    }
    ctx.restoreGState()
}

func notch(_ size: CGFloat) {
    let w = size * 0.30, h = size * 0.085, radius = size * 0.2237
    NSColor.black.setFill()
    NSBezierPath(roundedRect: CGRect(x: (size - w) / 2, y: size - radius * 0.35 - h, width: w, height: h + radius),
                 xRadius: h * 0.55, yRadius: h * 0.55).fill()
}

/// gap — окантовка цветом корпуса. Без неё соседние светлые фигуры слипаются
/// в одно пятно уже на 32 px.
func card(_ size: CGFloat, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
          color: NSColor, rotation: CGFloat = 0, corner: CGFloat = 0.18, gap: CGFloat = 0) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    ctx.saveGState()
    ctx.translateBy(x: size * x, y: size * y)
    ctx.rotate(by: rotation * .pi / 180)
    if gap > 0 {
        let g = size * gap
        let outer = CGRect(x: -size * w / 2 - g, y: -size * h / 2 - g,
                           width: size * w + g * 2, height: size * h + g * 2)
        bodyBottom.setFill()
        let r = min(outer.width, outer.height) * corner
        NSBezierPath(roundedRect: outer, xRadius: r, yRadius: r).fill()
    }
    let rect = CGRect(x: -size * w / 2, y: -size * h / 2, width: size * w, height: size * h)
    color.setFill()
    let r = min(rect.width, rect.height) * corner
    NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
    ctx.restoreGState()
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    body(size)
    // Шторка с двумя миниатюрами
    card(size, x: 0.46, y: 0.34, w: 0.68, h: 0.24, color: panelColor, corner: 0.32)
    card(size, x: 0.30, y: 0.34, w: 0.15, h: 0.14, color: bodyBottom)
    card(size, x: 0.50, y: 0.34, w: 0.15, h: 0.14, color: bodyBottom)
    // Артефакт, который уже вынули
    card(size, x: 0.70, y: 0.62, w: 0.32, h: 0.30, color: itemColor, rotation: 12, gap: 0.030)
    notch(size)

    return image
}

func png(_ image: NSImage, size: CGFloat) -> Data? {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
    rep.size = NSSize(width: size, height: size)
    return rep.representation(using: .png, properties: [:])
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for variant in variants {
    guard let data = png(drawIcon(size: variant.size), size: variant.size) else {
        print("не удалось нарисовать \(variant.name)")
        exit(1)
    }
    try data.write(to: iconset.appendingPathComponent("\(variant.name).png"))
}

let output = root.appendingPathComponent("Resources/AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    print("iconutil завершился с ошибкой \(process.terminationStatus)")
    exit(1)
}
try? FileManager.default.removeItem(at: iconset)
print("готово: \(output.path)")
