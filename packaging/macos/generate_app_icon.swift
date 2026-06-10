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

    var pixels: Int { Int(points * scale) }
}

let outputs = [
    IconOutput(filename: "icon_16x16.png",      points: 16,  scale: 1),
    IconOutput(filename: "icon_16x16@2x.png",   points: 16,  scale: 2),
    IconOutput(filename: "icon_32x32.png",       points: 32,  scale: 1),
    IconOutput(filename: "icon_32x32@2x.png",    points: 32,  scale: 2),
    IconOutput(filename: "icon_128x128.png",     points: 128, scale: 1),
    IconOutput(filename: "icon_128x128@2x.png",  points: 128, scale: 2),
    IconOutput(filename: "icon_256x256.png",     points: 256, scale: 1),
    IconOutput(filename: "icon_256x256@2x.png",  points: 256, scale: 2),
    IconOutput(filename: "icon_512x512.png",     points: 512, scale: 1),
    IconOutput(filename: "icon_512x512@2x.png",  points: 512, scale: 2),
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: CGSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }

    // ── 1. Clipped rounded-rect canvas (macOS icon shape) ─────────────────
    let radius = size * 0.225
    let canvasPath = NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                                  xRadius: radius, yRadius: radius)
    canvasPath.addClip()

    // ── 2. Background gradient: deep navy → vivid blue-indigo ─────────────
    let topColor    = CGColor(red: 0.22, green: 0.38, blue: 0.88, alpha: 1) // vibrant blue
    let bottomColor = CGColor(red: 0.06, green: 0.10, blue: 0.32, alpha: 1) // deep navy
    let colorSpace  = CGColorSpaceCreateDeviceRGB()
    if let gradient = CGGradient(colorsSpace: colorSpace,
                                  colors: [topColor, bottomColor] as CFArray,
                                  locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: size * 0.5, y: size),
                               end:   CGPoint(x: size * 0.5, y: 0),
                               options: [])
    }

    // ── 3. Document geometry ───────────────────────────────────────────────
    let dw     = size * 0.48        // document width
    let dh     = size * 0.56        // document height
    let dx     = (size - dw) / 2    // centered horizontally
    let dy     = size * 0.22        // vertical position
    let fold   = size * 0.115       // fold triangle leg

    // Document drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.025),
                  blur: size * 0.07,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))

    // White document body (missing top-right corner for fold)
    let docPath = NSBezierPath()
    let docCorner = size * 0.022
    docPath.move(to:       CGPoint(x: dx + docCorner,       y: dy))
    docPath.line(to:       CGPoint(x: dx + dw - fold,       y: dy))          // top edge
    docPath.line(to:       CGPoint(x: dx + dw,              y: dy + fold))   // fold diagonal
    docPath.line(to:       CGPoint(x: dx + dw,              y: dy + dh - docCorner)) // right edge
    docPath.curve(to:      CGPoint(x: dx + dw - docCorner,  y: dy + dh),     // bottom-right corner
                  controlPoint1: CGPoint(x: dx + dw, y: dy + dh),
                  controlPoint2: CGPoint(x: dx + dw, y: dy + dh))
    docPath.line(to:       CGPoint(x: dx + docCorner,       y: dy + dh))     // bottom edge
    docPath.curve(to:      CGPoint(x: dx,                   y: dy + dh - docCorner), // bottom-left
                  controlPoint1: CGPoint(x: dx, y: dy + dh),
                  controlPoint2: CGPoint(x: dx, y: dy + dh))
    docPath.line(to:       CGPoint(x: dx,                   y: dy + docCorner)) // left edge
    docPath.curve(to:      CGPoint(x: dx + docCorner,       y: dy),          // top-left corner
                  controlPoint1: CGPoint(x: dx, y: dy),
                  controlPoint2: CGPoint(x: dx, y: dy))
    docPath.close()
    NSColor.white.setFill()
    docPath.fill()
    ctx.restoreGState()

    // ── 4. Fold triangle (silver-blue tint) ───────────────────────────────
    let foldPath = NSBezierPath()
    foldPath.move(to:  CGPoint(x: dx + dw - fold, y: dy))
    foldPath.line(to:  CGPoint(x: dx + dw,        y: dy + fold))
    foldPath.line(to:  CGPoint(x: dx + dw - fold, y: dy + fold))
    foldPath.close()
    NSColor(calibratedRed: 0.72, green: 0.80, blue: 0.92, alpha: 1).setFill()
    foldPath.fill()

    // Fold edge crease (subtle dividing line)
    let creasePath = NSBezierPath()
    creasePath.move(to: CGPoint(x: dx + dw - fold, y: dy))
    creasePath.line(to: CGPoint(x: dx + dw - fold, y: dy + fold))
    NSColor(calibratedRed: 0.60, green: 0.70, blue: 0.84, alpha: 0.6).setStroke()
    creasePath.lineWidth = max(size * 0.008, 0.5)
    creasePath.stroke()

    // ── 5. Gold accent bar at top of document ─────────────────────────────
    let barH    = size * 0.048
    let barPath = NSBezierPath(roundedRect: CGRect(x: dx, y: dy + dh - barH, width: dw - fold, height: barH),
                                xRadius: 0, yRadius: 0)
    // Clamp top corners to match document corner radius
    let goldTop    = CGColor(red: 0.98, green: 0.78, blue: 0.22, alpha: 1) // bright gold
    let goldBottom = CGColor(red: 0.88, green: 0.55, blue: 0.08, alpha: 1) // amber
    ctx.saveGState()
    barPath.addClip()
    if let barGradient = CGGradient(colorsSpace: colorSpace,
                                     colors: [goldTop, goldBottom] as CFArray,
                                     locations: [0, 1]) {
        ctx.drawLinearGradient(barGradient,
                               start: CGPoint(x: 0, y: dy + dh),
                               end:   CGPoint(x: 0, y: dy + dh - barH),
                               options: [])
    }
    ctx.restoreGState()

    // ── 6. Text lines ─────────────────────────────────────────────────────
    let lineColor = NSColor(calibratedRed: 0.60, green: 0.65, blue: 0.74, alpha: 1)
    lineColor.setFill()

    let lx1    = dx + size * 0.075
    let lx2    = dx + dw - size * 0.055
    let lh     = max(size * 0.026, 1.0)
    let lFirst = dy + dh * 0.30
    let lStep  = size * 0.093

    let lineWidths: [CGFloat] = [1.0, 1.0, 1.0, 0.55]
    for (i, wScale) in lineWidths.enumerated() {
        let y = lFirst + CGFloat(i) * lStep
        let w = (lx2 - lx1) * wScale
        NSBezierPath(roundedRect: CGRect(x: lx1, y: y, width: w, height: lh),
                     xRadius: lh / 2, yRadius: lh / 2).fill()
    }

    // ── 7. Small golden "forge" spark at bottom-right ─────────────────────
    let sparkX  = dx + dw * 0.78
    let sparkY  = dy + dh * 0.16
    let sparkR  = size * 0.055
    ctx.saveGState()
    if let sparkGrad = CGGradient(colorsSpace: colorSpace,
                                   colors: [goldTop, CGColor(red: 0.98, green: 0.72, blue: 0.18, alpha: 0)] as CFArray,
                                   locations: [0, 1]) {
        ctx.drawRadialGradient(sparkGrad,
                               startCenter: CGPoint(x: sparkX, y: sparkY), startRadius: 0,
                               endCenter:   CGPoint(x: sparkX, y: sparkY), endRadius: sparkR,
                               options: [])
    }
    ctx.restoreGState()

    return image
}

for output in outputs {
    let img = drawIcon(size: CGFloat(output.pixels))
    guard let tiff   = img.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data   = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to render \(output.filename)")
    }
    try data.write(to: iconset.appendingPathComponent(output.filename), options: [.atomic])
}

print("Created \(iconset.path)")
