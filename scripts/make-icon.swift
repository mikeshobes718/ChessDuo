// Renders the Chess Duo app icon. Run: swift scripts/make-icon.swift <out.png> [size]
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let size = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2])! : 1024
let s = CGFloat(size)
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// Background: deep ink gradient.
if let grad = CGGradient(colorsSpace: space, colors: [color(0x2A2140), color(0x14121C)] as CFArray, locations: [0, 1]) {
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
}

// Tilted 4x4 board panel with perspective feel (a parallelogram).
ctx.saveGState()
let boardW = s * 0.72, boardH = s * 0.44
let origin = CGPoint(x: (s - boardW) / 2, y: s * 0.20)
let skew: CGFloat = s * 0.10
ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.06, color: color(0x000000, 0.5))
let panel = CGMutablePath()
panel.move(to: CGPoint(x: origin.x + skew, y: origin.y + boardH))
panel.addLine(to: CGPoint(x: origin.x + boardW - skew, y: origin.y + boardH))
panel.addLine(to: CGPoint(x: origin.x + boardW, y: origin.y))
panel.addLine(to: CGPoint(x: origin.x, y: origin.y))
panel.closeSubpath()
ctx.addPath(panel)
ctx.setFillColor(color(0x5A3A24))
ctx.fillPath()
ctx.restoreGState()

// Squares in perspective.
let n = 6
for row in 0..<n {
    let t0 = CGFloat(row) / CGFloat(n), t1 = CGFloat(row + 1) / CGFloat(n)
    let y0 = origin.y + boardH * (1 - t0), y1 = origin.y + boardH * (1 - t1)
    let leftX0 = origin.x + skew * (1 - t0), rightX0 = origin.x + boardW - skew * (1 - t0)
    let leftX1 = origin.x + skew * (1 - t1), rightX1 = origin.x + boardW - skew * (1 - t1)
    for col in 0..<n {
        let c0 = CGFloat(col) / CGFloat(n), c1 = CGFloat(col + 1) / CGFloat(n)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: leftX0 + (rightX0 - leftX0) * c0, y: y0))
        p.addLine(to: CGPoint(x: leftX0 + (rightX0 - leftX0) * c1, y: y0))
        p.addLine(to: CGPoint(x: leftX1 + (rightX1 - leftX1) * c1, y: y1))
        p.addLine(to: CGPoint(x: leftX1 + (rightX1 - leftX1) * c0, y: y1))
        p.closeSubpath()
        ctx.addPath(p)
        ctx.setFillColor((row + col) % 2 == 0 ? color(0xEBDDC0) : color(0x8C5A38))
        ctx.fillPath()
    }
}

// Two kings: gold (white) and rose (black), as friendly silhouettes.
func king(cx: CGFloat, baseY: CGFloat, h: CGFloat, fill: CGColor, stroke: CGColor) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -h * 0.03), blur: h * 0.08, color: color(0x000000, 0.45))
    let p = CGMutablePath()
    let w = h * 0.62
    // base
    p.addRoundedRect(in: CGRect(x: cx - w / 2, y: baseY, width: w, height: h * 0.10), cornerWidth: h * 0.03, cornerHeight: h * 0.03)
    // stem
    p.move(to: CGPoint(x: cx - w * 0.30, y: baseY + h * 0.10))
    p.addLine(to: CGPoint(x: cx + w * 0.30, y: baseY + h * 0.10))
    p.addLine(to: CGPoint(x: cx + w * 0.42, y: baseY + h * 0.55))
    p.addLine(to: CGPoint(x: cx - w * 0.42, y: baseY + h * 0.55))
    p.closeSubpath()
    // crown
    p.addEllipse(in: CGRect(x: cx - w * 0.48, y: baseY + h * 0.50, width: w * 0.96, height: h * 0.22))
    // cross
    p.addRect(CGRect(x: cx - h * 0.035, y: baseY + h * 0.70, width: h * 0.07, height: h * 0.30))
    p.addRect(CGRect(x: cx - h * 0.12, y: baseY + h * 0.84, width: h * 0.24, height: h * 0.07))
    ctx.addPath(p)
    ctx.setFillColor(fill)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(p)
    ctx.setStrokeColor(stroke)
    ctx.setLineWidth(h * 0.018)
    ctx.strokePath()
}
king(cx: s * 0.37, baseY: s * 0.30, h: s * 0.50, fill: color(0xF3E7CF), stroke: color(0x8A6B3C, 0.6))
king(cx: s * 0.63, baseY: s * 0.30, h: s * 0.50, fill: color(0xD9556E), stroke: color(0x5A1F2E, 0.6))

// Gold glint at top-left.
if let glow = CGGradient(colorsSpace: space, colors: [color(0xE0A84A, 0.35), color(0xE0A84A, 0.0)] as CFArray, locations: [0, 1]) {
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: s * 0.2, y: s * 0.85), startRadius: 0, endCenter: CGPoint(x: s * 0.2, y: s * 0.85), endRadius: s * 0.6, options: [])
}

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(2) }
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out)")
