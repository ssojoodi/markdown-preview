#!/usr/bin/env swift

import AppKit
import Foundation

func drawText(_ text: String, in rect: CGRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .center, letterSpacing: Double = 0) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: letterSpacing
    ]

    text.draw(in: rect, withAttributes: attributes)
}

func roundedRect(_ rect: CGRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()

    if let stroke {
        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: render_dmg_background.swift <output.png>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let size = CGSize(width: 660, height: 400)
let image = NSImage(size: size)

image.lockFocus()

let bounds = CGRect(origin: .zero, size: size)
NSGradient(
    starting: NSColor(calibratedRed: 0.985, green: 0.976, blue: 0.949, alpha: 1),
    ending: NSColor(calibratedRed: 0.929, green: 0.965, blue: 0.975, alpha: 1)
)?.draw(in: bounds, angle: -35)

roundedRect(
    CGRect(x: 26, y: 26, width: 608, height: 348),
    radius: 28,
    fill: .clear,
    stroke: NSColor(calibratedRed: 0.82, green: 0.80, blue: 0.74, alpha: 0.82)
)

let titleFont = NSFont(name: "Baskerville-SemiBold", size: 34) ?? NSFont.systemFont(ofSize: 34, weight: .semibold)
drawText(
    "Markdown Preview",
    in: CGRect(x: 60, y: 320, width: 540, height: 42),
    font: titleFont,
    color: NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.09, alpha: 1)
)

drawText(
    "DRAG TO INSTALL",
    in: CGRect(x: 60, y: 292, width: 540, height: 22),
    font: NSFont.systemFont(ofSize: 14, weight: .medium),
    color: NSColor(calibratedRed: 0.36, green: 0.43, blue: 0.45, alpha: 1),
    letterSpacing: 2
)

let panelFill = NSColor(calibratedWhite: 1, alpha: 0.92)
let panelStroke = NSColor(calibratedRed: 0.87, green: 0.84, blue: 0.78, alpha: 0.9)
roundedRect(CGRect(x: 90, y: 92, width: 158, height: 158), radius: 32, fill: panelFill, stroke: panelStroke)
roundedRect(CGRect(x: 412, y: 92, width: 158, height: 158), radius: 32, fill: panelFill, stroke: panelStroke)

let arrowColor = NSColor(calibratedRed: 0.19, green: 0.49, blue: 0.57, alpha: 1)
arrowColor.setStroke()
let arrow = NSBezierPath()
arrow.lineWidth = 6
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: CGPoint(x: 292, y: 171))
arrow.line(to: CGPoint(x: 368, y: 171))
arrow.move(to: CGPoint(x: 356, y: 185))
arrow.line(to: CGPoint(x: 374, y: 171))
arrow.line(to: CGPoint(x: 356, y: 157))
arrow.stroke()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("failed to encode PNG\n", stderr)
    exit(1)
}

do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try png.write(to: outputURL)
} catch {
    fputs("write failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
