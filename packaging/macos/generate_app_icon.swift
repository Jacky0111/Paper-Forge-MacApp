import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

struct IconOutput {
    let filename: String
    let points: CGFloat
    let scale: CGFloat

    var pixels: Int {
        Int(points * scale)
    }
}

let outputs = [
    IconOutput(filename: "icon_16x16.png", points: 16, scale: 1),
    IconOutput(filename: "icon_16x16@2x.png", points: 16, scale: 2),
    IconOutput(filename: "icon_32x32.png", points: 32, scale: 1),
    IconOutput(filename: "icon_32x32@2x.png", points: 32, scale: 2),
    IconOutput(filename: "icon_128x128.png", points: 128, scale: 1),
    IconOutput(filename: "icon_128x128@2x.png", points: 128, scale: 2),
    IconOutput(filename: "icon_256x256.png", points: 256, scale: 1),
    IconOutput(filename: "icon_256x256@2x.png", points: 256, scale: 2),
    IconOutput(filename: "icon_512x512.png", points: 512, scale: 1),
    IconOutput(filename: "icon_512x512@2x.png", points: 512, scale: 2)
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: CGSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.16, alpha: 1).setFill()
    canvas.fill()

    let background = NSBezierPath(roundedRect: canvas.insetBy(dx: size * 0.07, dy: size * 0.07), xRadius: size * 0.2, yRadius: size * 0.2)
    NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.16, alpha: 1).setFill()
    background.fill()

    let forge = NSBezierPath(roundedRect: canvas.insetBy(dx: size * 0.17, dy: size * 0.17), xRadius: size * 0.12, yRadius: size * 0.12)
    NSColor(calibratedRed: 0.94, green: 0.80, blue: 0.38, alpha: 1).setFill()
    forge.fill()

    let page = NSBezierPath(roundedRect: CGRect(x: size * 0.31, y: size * 0.25, width: size * 0.38, height: size * 0.5), xRadius: size * 0.035, yRadius: size * 0.035)
    NSColor.white.setFill()
    page.fill()

    let fold = NSBezierPath()
    fold.move(to: CGPoint(x: size * 0.59, y: size * 0.75))
    fold.line(to: CGPoint(x: size * 0.69, y: size * 0.65))
    fold.line(to: CGPoint(x: size * 0.59, y: size * 0.65))
    fold.close()
    NSColor(calibratedRed: 0.82, green: 0.88, blue: 0.90, alpha: 1).setFill()
    fold.fill()

    NSColor(calibratedRed: 0.18, green: 0.26, blue: 0.31, alpha: 1).setStroke()
    for row in 0..<3 {
        let y = size * (0.41 + CGFloat(row) * 0.09)
        let line = NSBezierPath()
        line.lineWidth = max(size * 0.018, 1)
        line.move(to: CGPoint(x: size * 0.38, y: y))
        line.line(to: CGPoint(x: size * 0.62, y: y))
        line.stroke()
    }

    return image
}

for output in outputs {
    let image = drawIcon(size: CGFloat(output.pixels))
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to render \(output.filename)")
    }

    try data.write(to: iconset.appendingPathComponent(output.filename), options: [.atomic])
}

print("Created \(iconset.path)")
