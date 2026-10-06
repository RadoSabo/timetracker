// Renders AppIcon.icns and the menu bar template icon. Usage: swift scripts/icon.swift <outDir>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist"
let fm = FileManager.default

func render(_ size: CGFloat, _ draw: (CGContext, CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    draw(ctx.cgContext, size)
    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

/// App icon: rounded indigo→blue square, white clock, green check badge.
func appIcon(_ c: CGContext, _ s: CGFloat) {
    let inset = s * 0.05
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = CGPath(roundedRect: rect, cornerWidth: s * 0.21, cornerHeight: s * 0.21, transform: nil)
    c.saveGState(); c.addPath(path); c.clip()
    let colors = [CGColor(red: 0.29, green: 0.36, blue: 0.95, alpha: 1), CGColor(red: 0.10, green: 0.60, blue: 0.95, alpha: 1)] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    c.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    c.restoreGState()
    // clock face
    let center = CGPoint(x: s * 0.5, y: s * 0.52), r = s * 0.28
    c.setStrokeColor(.white); c.setLineWidth(s * 0.055); c.setLineCap(.round)
    c.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
    c.setFillColor(CGColor(gray: 1, alpha: 0.18)); c.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
    c.move(to: center); c.addLine(to: CGPoint(x: center.x, y: center.y + r * 0.62)); c.strokePath()          // hour hand
    c.move(to: center); c.addLine(to: CGPoint(x: center.x + r * 0.5, y: center.y + r * 0.22)); c.strokePath() // minute hand
    // check badge
    let br = s * 0.15, bc = CGPoint(x: s * 0.76, y: s * 0.25)
    c.setFillColor(CGColor(red: 0.20, green: 0.78, blue: 0.45, alpha: 1))
    c.fillEllipse(in: CGRect(x: bc.x - br, y: bc.y - br, width: 2 * br, height: 2 * br))
    c.setStrokeColor(.white); c.setLineWidth(s * 0.04)
    c.move(to: CGPoint(x: bc.x - br * 0.45, y: bc.y)); c.addLine(to: CGPoint(x: bc.x - br * 0.1, y: bc.y - br * 0.35)); c.addLine(to: CGPoint(x: bc.x + br * 0.5, y: bc.y + br * 0.4)); c.strokePath()
}

/// Menu bar template: black clock with a check, alpha only (macOS tints it).
func menuIcon(_ c: CGContext, _ s: CGFloat) {
    let center = CGPoint(x: s * 0.42, y: s * 0.5), r = s * 0.34
    c.setStrokeColor(.black); c.setLineWidth(s * 0.11); c.setLineCap(.round)
    c.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
    c.move(to: center); c.addLine(to: CGPoint(x: center.x, y: center.y + r * 0.6)); c.strokePath()
    c.move(to: center); c.addLine(to: CGPoint(x: center.x + r * 0.5, y: center.y + r * 0.2)); c.strokePath()
    let bc = CGPoint(x: s * 0.8, y: s * 0.24), br = s * 0.2
    c.setFillColor(.black); c.fillEllipse(in: CGRect(x: bc.x - br, y: bc.y - br, width: 2 * br, height: 2 * br))
    c.setBlendMode(.clear); c.setLineWidth(s * 0.07)
    c.move(to: CGPoint(x: bc.x - br * 0.45, y: bc.y)); c.addLine(to: CGPoint(x: bc.x - br * 0.1, y: bc.y - br * 0.35)); c.addLine(to: CGPoint(x: bc.x + br * 0.5, y: bc.y + br * 0.4)); c.strokePath()
}

let iconset = "\(out)/AppIcon.iconset"
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = CGFloat(base * scale)
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! render(px, appIcon).write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
    }
}
try! render(18, menuIcon).write(to: URL(fileURLWithPath: "\(out)/MenuIcon.png"))
try! render(36, menuIcon).write(to: URL(fileURLWithPath: "\(out)/MenuIcon@2x.png"))
try! render(256, appIcon).write(to: URL(fileURLWithPath: "\(out)/AppIcon-preview.png"))
