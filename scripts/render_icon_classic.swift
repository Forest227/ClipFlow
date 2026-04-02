import AppKit
import CoreGraphics
import Foundation

let outputArgument = CommandLine.arguments.dropFirst().first
let outputPath = outputArgument ?? "/Users/wuqicheng/AI 代码项目/剪切板/assets/icon/ClipFlow-classic-icon-1024.png"
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

let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let cg = context.cgContext
cg.setAllowsAntialiasing(true)
cg.setShouldAntialias(true)

let canvasRect = CGRect(origin: .zero, size: canvasSize)
cg.clear(canvasRect)

let backgroundRect = canvasRect.insetBy(dx: 44, dy: 44)
let backgroundPath = CGPath(
    roundedRect: backgroundRect,
    cornerWidth: 224,
    cornerHeight: 224,
    transform: nil
)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawLinearGradient(in path: CGPath, colors: [NSColor], start: CGPoint, end: CGPoint) {
    cg.saveGState()
    cg.addPath(path)
    cg.clip()

    let cgColors = colors.map { $0.cgColor } as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil)!
    cg.drawLinearGradient(gradient, start: start, end: end, options: [])
    cg.restoreGState()
}

func drawRadialGlow(center: CGPoint, radius: CGFloat, color: NSColor) {
    cg.saveGState()
    cg.addPath(backgroundPath)
    cg.clip()

    let colors = [color.withAlphaComponent(0.9).cgColor, color.withAlphaComponent(0.0).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0])!
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

func drawShadowedPath(_ path: CGPath, shadowColor: NSColor, blur: CGFloat, offset: CGSize) {
    cg.saveGState()
    cg.setShadow(offset: offset, blur: blur, color: shadowColor.cgColor)
    cg.addPath(path)
    cg.setFillColor(NSColor.black.withAlphaComponent(0.16).cgColor)
    cg.fillPath()
    cg.restoreGState()
}

drawShadowedPath(
    backgroundPath,
    shadowColor: color(8, 10, 18, 0.42),
    blur: 42,
    offset: CGSize(width: 0, height: -20)
)

drawLinearGradient(
    in: backgroundPath,
    colors: [
        color(31, 40, 58),
        color(22, 31, 48),
        color(14, 20, 33)
    ],
    start: CGPoint(x: backgroundRect.minX, y: backgroundRect.maxY),
    end: CGPoint(x: backgroundRect.maxX, y: backgroundRect.minY)
)

drawRadialGlow(center: CGPoint(x: 300, y: 770), radius: 330, color: color(244, 157, 78, 0.34))
drawRadialGlow(center: CGPoint(x: 760, y: 260), radius: 340, color: color(84, 176, 255, 0.32))

cg.saveGState()
cg.addPath(backgroundPath)
cg.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
cg.setLineWidth(4)
cg.strokePath()
cg.restoreGState()

let ribbonPath = CGMutablePath()
ribbonPath.move(to: CGPoint(x: 754, y: 748))
ribbonPath.addCurve(
    to: CGPoint(x: 366, y: 792),
    control1: CGPoint(x: 635, y: 864),
    control2: CGPoint(x: 470, y: 860)
)
ribbonPath.addCurve(
    to: CGPoint(x: 246, y: 514),
    control1: CGPoint(x: 255, y: 735),
    control2: CGPoint(x: 208, y: 630)
)
ribbonPath.addCurve(
    to: CGPoint(x: 412, y: 252),
    control1: CGPoint(x: 272, y: 398),
    control2: CGPoint(x: 320, y: 286)
)
ribbonPath.addCurve(
    to: CGPoint(x: 748, y: 314),
    control1: CGPoint(x: 528, y: 224),
    control2: CGPoint(x: 662, y: 238)
)

cg.saveGState()
cg.addPath(ribbonPath)
cg.setLineWidth(98)
cg.setLineCap(.round)
cg.replacePathWithStrokedPath()
cg.clip()

let ribbonColors = [
    color(248, 167, 88).cgColor,
    color(128, 203, 255).cgColor,
    color(74, 152, 255).cgColor
] as CFArray
let ribbonGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: ribbonColors, locations: [0.0, 0.6, 1.0])!
cg.drawLinearGradient(
    ribbonGradient,
    start: CGPoint(x: 248, y: 724),
    end: CGPoint(x: 796, y: 268),
    options: []
)
cg.restoreGState()

cg.saveGState()
cg.addPath(ribbonPath)
cg.setLineWidth(18)
cg.setLineCap(.round)
cg.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
cg.strokePath()
cg.restoreGState()

func cardPath(rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawCard(rect: CGRect, fillColors: [NSColor], stroke: NSColor, shadowOpacity: CGFloat) {
    let path = cardPath(rect: rect, radius: 54)
    drawShadowedPath(path, shadowColor: color(8, 10, 18, shadowOpacity), blur: 24, offset: CGSize(width: 0, height: -10))
    drawLinearGradient(
        in: path,
        colors: fillColors,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY)
    )
    cg.saveGState()
    cg.addPath(path)
    cg.setStrokeColor(stroke.cgColor)
    cg.setLineWidth(3)
    cg.strokePath()
    cg.restoreGState()
}

let backCard = CGRect(x: 454, y: 474, width: 256, height: 188)
let middleCard = CGRect(x: 372, y: 390, width: 306, height: 220)
let frontCard = CGRect(x: 286, y: 304, width: 360, height: 254)

drawCard(
    rect: backCard,
    fillColors: [color(53, 87, 140, 0.74), color(35, 54, 92, 0.94)],
    stroke: color(165, 215, 255, 0.22),
    shadowOpacity: 0.22
)
drawCard(
    rect: middleCard,
    fillColors: [color(83, 126, 191, 0.88), color(47, 80, 136, 0.98)],
    stroke: color(196, 230, 255, 0.28),
    shadowOpacity: 0.28
)
drawCard(
    rect: frontCard,
    fillColors: [color(251, 253, 255, 0.98), color(215, 231, 250, 0.98)],
    stroke: color(255, 255, 255, 0.56),
    shadowOpacity: 0.30
)

func drawRoundedBar(rect: CGRect, color: NSColor) {
    let path = CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil)
    cg.saveGState()
    cg.addPath(path)
    cg.setFillColor(color.cgColor)
    cg.fillPath()
    cg.restoreGState()
}

drawRoundedBar(rect: CGRect(x: 344, y: 486, width: 186, height: 26), color: color(48, 103, 184, 0.94))
drawRoundedBar(rect: CGRect(x: 344, y: 444, width: 238, height: 20), color: color(83, 134, 205, 0.82))
drawRoundedBar(rect: CGRect(x: 344, y: 406, width: 172, height: 20), color: color(246, 163, 83, 0.92))

for x in stride(from: 344.0, through: 530.0, by: 62.0) {
    let chip = CGRect(x: x, y: 360, width: 42, height: 16)
    drawRoundedBar(rect: chip, color: color(125, 153, 199, 0.72))
}

let cursorPath = CGMutablePath()
cursorPath.move(to: CGPoint(x: 546, y: 284))
cursorPath.addLine(to: CGPoint(x: 650, y: 330))
cursorPath.addLine(to: CGPoint(x: 606, y: 362))
cursorPath.addLine(to: CGPoint(x: 654, y: 430))
cursorPath.addLine(to: CGPoint(x: 614, y: 454))
cursorPath.addLine(to: CGPoint(x: 566, y: 384))
cursorPath.addLine(to: CGPoint(x: 534, y: 430))
cursorPath.closeSubpath()

drawShadowedPath(cursorPath, shadowColor: color(9, 12, 19, 0.34), blur: 22, offset: CGSize(width: 0, height: -8))

cg.saveGState()
cg.addPath(cursorPath)
cg.setFillColor(NSColor.white.cgColor)
cg.fillPath()
cg.restoreGState()

cg.saveGState()
cg.addPath(cursorPath)
cg.setStrokeColor(color(63, 130, 224, 0.54).cgColor)
cg.setLineWidth(6)
cg.strokePath()
cg.restoreGState()

let privacyDot = CGPath(ellipseIn: CGRect(x: 660, y: 282, width: 78, height: 78), transform: nil)
drawShadowedPath(privacyDot, shadowColor: color(9, 12, 19, 0.22), blur: 16, offset: CGSize(width: 0, height: -6))
drawLinearGradient(
    in: privacyDot,
    colors: [color(247, 171, 100), color(235, 112, 84)],
    start: CGPoint(x: 662, y: 352),
    end: CGPoint(x: 734, y: 280)
)

let shield = CGMutablePath()
shield.move(to: CGPoint(x: 698, y: 340))
shield.addLine(to: CGPoint(x: 718, y: 332))
shield.addLine(to: CGPoint(x: 718, y: 312))
shield.addCurve(
    to: CGPoint(x: 698, y: 292),
    control1: CGPoint(x: 718, y: 302),
    control2: CGPoint(x: 709, y: 294)
)
shield.addCurve(
    to: CGPoint(x: 678, y: 312),
    control1: CGPoint(x: 687, y: 294),
    control2: CGPoint(x: 678, y: 302)
)
shield.addLine(to: CGPoint(x: 678, y: 332))
shield.closeSubpath()

cg.saveGState()
cg.addPath(shield)
cg.setFillColor(NSColor.white.withAlphaComponent(0.96).cgColor)
cg.fillPath()
cg.restoreGState()

let outputDirectory = outputURL.deletingLastPathComponent()
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let pngData = bitmap.representation(using: .png, properties: [:])!
try pngData.write(to: outputURL)

NSGraphicsContext.restoreGraphicsState()

print("Rendered classic icon to \(outputURL.path)")
