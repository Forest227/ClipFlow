import AppKit
import CoreGraphics
import CoreText
import Foundation

let outputArgument = CommandLine.arguments.dropFirst().first
let outputPath = outputArgument ?? "/Users/wuqicheng/AI 代码项目/剪切板/assets/icon/ClipFlow-icon-1024.png"
let outputURL = URL(fileURLWithPath: outputPath)

let canvasSize = CGSize(width: 1024, height: 1024)
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext

let cg = graphicsContext.cgContext
cg.setAllowsAntialiasing(true)
cg.setShouldAntialias(true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawLinearGradient(in path: CGPath, colors: [NSColor], start: CGPoint, end: CGPoint) {
    cg.saveGState()
    cg.addPath(path)
    cg.clip()

    let cgColors = colors.map(\.cgColor) as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil)!
    cg.drawLinearGradient(gradient, start: start, end: end, options: [])
    cg.restoreGState()
}

func drawRadialGlow(in clipPath: CGPath, center: CGPoint, radius: CGFloat, color: NSColor) {
    cg.saveGState()
    cg.addPath(clipPath)
    cg.clip()

    let colors = [color.withAlphaComponent(0.58).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    cg.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
    cg.restoreGState()
}

func fillPath(_ path: CGPath, color: NSColor) {
    cg.saveGState()
    cg.addPath(path)
    cg.setFillColor(color.cgColor)
    cg.fillPath()
    cg.restoreGState()
}

func strokePath(_ path: CGPath, color: NSColor, width: CGFloat) {
    cg.saveGState()
    cg.addPath(path)
    cg.setStrokeColor(color.cgColor)
    cg.setLineWidth(width)
    cg.strokePath()
    cg.restoreGState()
}

func shadowedFill(path: CGPath, shadow: NSColor, blur: CGFloat, offset: CGSize, fill: NSColor) {
    cg.saveGState()
    cg.setShadow(offset: offset, blur: blur, color: shadow.cgColor)
    cg.addPath(path)
    cg.setFillColor(fill.cgColor)
    cg.fillPath()
    cg.restoreGState()
}

func preferredGlyphFont(size: CGFloat) -> NSFont {
    let preferredNames = [
        "Avenir-Heavy",
        "Avenir-Black",
        "AvenirNext-Heavy"
    ]

    for name in preferredNames {
        if let font = NSFont(name: name, size: size) {
            return font
        }
    }

    return NSFont.systemFont(ofSize: size, weight: .heavy)
}

func makeSystemGlyphPath(character: Character, fontSize: CGFloat) -> CGPath? {
    let font = preferredGlyphFont(size: fontSize)
    let ctFont = font as CTFont

    guard let scalar = character.unicodeScalars.first else {
        return nil
    }

    var input = UniChar(scalar.value)
    var glyph = CGGlyph()

    guard CTFontGetGlyphsForCharacters(ctFont, &input, &glyph, 1),
          let path = CTFontCreatePathForGlyph(ctFont, glyph, nil) else {
        return nil
    }

    return path
}

let canvasRect = CGRect(origin: .zero, size: canvasSize)
cg.clear(canvasRect)

let backgroundRect = canvasRect.insetBy(dx: 44, dy: 44)
let backgroundPath = CGPath(
    roundedRect: backgroundRect,
    cornerWidth: 224,
    cornerHeight: 224,
    transform: nil
)

shadowedFill(
    path: backgroundPath,
    shadow: color(6, 8, 14, 0.40),
    blur: 42,
    offset: CGSize(width: 0, height: -20),
    fill: color(9, 13, 22)
)

drawLinearGradient(
    in: backgroundPath,
    colors: [
        color(26, 37, 58),
        color(16, 24, 40),
        color(10, 16, 28)
    ],
    start: CGPoint(x: backgroundRect.minX, y: backgroundRect.maxY),
    end: CGPoint(x: backgroundRect.maxX, y: backgroundRect.minY)
)

drawRadialGlow(
    in: backgroundPath,
    center: CGPoint(x: 496, y: 554),
    radius: 268,
    color: color(247, 159, 89, 0.24)
)

strokePath(backgroundPath, color: NSColor.white.withAlphaComponent(0.10), width: 4)

let rawGlyphPath = makeSystemGlyphPath(character: "C", fontSize: 640)!
let glyphBox = rawGlyphPath.boundingBox
let scale = min(536 / glyphBox.width, 578 / glyphBox.height)
var glyphTransform = CGAffineTransform(scaleX: scale, y: scale)
let scaledGlyphPath = rawGlyphPath.copy(using: &glyphTransform)!
let scaledBox = scaledGlyphPath.boundingBox
let targetCenter = CGPoint(x: backgroundRect.midX - 2, y: backgroundRect.midY - 8)
glyphTransform = CGAffineTransform(
    translationX: targetCenter.x - scaledBox.midX,
    y: targetCenter.y - scaledBox.midY
)
let glyphPath = scaledGlyphPath.copy(using: &glyphTransform)!

shadowedFill(
    path: glyphPath,
    shadow: color(6, 8, 14, 0.22),
    blur: 24,
    offset: CGSize(width: 0, height: -10),
    fill: color(243, 149, 72, 0.98)
)

cg.saveGState()
cg.addPath(glyphPath)
cg.clip()

let cGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        color(255, 216, 168).cgColor,
        color(247, 166, 88).cgColor,
        color(237, 140, 60).cgColor
    ] as CFArray,
    locations: [0, 0.5, 1]
)!
cg.drawLinearGradient(
    cGradient,
    start: CGPoint(x: backgroundRect.minX + 162, y: backgroundRect.maxY - 120),
    end: CGPoint(x: backgroundRect.maxX - 144, y: backgroundRect.minY + 134),
    options: []
)
cg.restoreGState()

strokePath(glyphPath, color: NSColor.white.withAlphaComponent(0.10), width: 4)

let outputDirectory = outputURL.deletingLastPathComponent()
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let pngData = bitmap.representation(using: .png, properties: [:])!
try pngData.write(to: outputURL)

NSGraphicsContext.restoreGraphicsState()

print("Rendered icon to \(outputURL.path)")
