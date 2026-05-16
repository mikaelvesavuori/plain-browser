#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceLogo = root.appendingPathComponent("plain-logo-1024.png")
let packaging = root.appendingPathComponent("packaging", isDirectory: true)
let iconset = packaging.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let output = packaging.appendingPathComponent("AppIcon.icns")

guard FileManager.default.fileExists(atPath: sourceLogo.path) else {
    throw NSError(
        domain: "PlainIcon",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing source logo: \(sourceLogo.path)"]
    )
}

guard let logo = NSImage(contentsOf: sourceLogo) else {
    throw NSError(
        domain: "PlainIcon",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not read source logo: \(sourceLogo.path)"]
    )
}

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let appIconSizes: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for size in appIconSizes {
    let image = drawAppIcon(from: logo, size: size.pixels)
    let fileURL = iconset.appendingPathComponent(size.name)
    try writePNG(image, to: fileURL)
}

let siteAssets = root.appendingPathComponent("site/assets", isDirectory: true)
try FileManager.default.createDirectory(at: siteAssets, withIntermediateDirectories: true)
try writePNG(drawSquareIcon(from: logo, size: 128), to: siteAssets.appendingPathComponent("plain-icon-128.png"))
try writePNG(drawSquareIcon(from: logo, size: 512), to: siteAssets.appendingPathComponent("plain-icon-512.png"))

let docsAssets = root.appendingPathComponent("docs/src/assets", isDirectory: true)
let docsPublic = root.appendingPathComponent("docs/public", isDirectory: true)
try FileManager.default.createDirectory(at: docsAssets, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: docsPublic, withIntermediateDirectories: true)
try writePNG(drawSquareIcon(from: logo, size: 512), to: docsAssets.appendingPathComponent("logo.png"))
try writePNG(drawSquareIcon(from: logo, size: 128), to: docsPublic.appendingPathComponent("favicon.png"))

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "PlainIcon", code: Int(process.terminationStatus))
}

func drawAppIcon(from source: NSImage, size: CGFloat) -> NSImage {
    drawIcon(from: source, size: size, rounded: true)
}

func drawSquareIcon(from source: NSImage, size: CGFloat) -> NSImage {
    drawIcon(from: source, size: size, rounded: false)
}

func drawIcon(from source: NSImage, size: CGFloat, rounded: Bool) -> NSImage {
    let pixelSize = Int(size.rounded())
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return NSImage(size: NSSize(width: size, height: size))
    }

    bitmap.size = NSSize(width: size, height: size)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current = context

    context?.imageInterpolation = .high

    NSColor.clear.setFill()
    rect.fill()

    if rounded {
        let iconRect = rect.insetBy(dx: size * 0.035, dy: size * 0.035)
        let cornerRadius = size * 0.215
        let background = NSBezierPath(
            roundedRect: iconRect,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )

        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -size * 0.025)
        shadow.shadowBlurRadius = size * 0.075
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.set()

        NSColor.black.setFill()
        background.fill()
        NSShadow().set()

        NSGraphicsContext.saveGraphicsState()
        background.addClip()
        drawSource(source, in: iconRect)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.10).setStroke()
        background.lineWidth = max(1, size * 0.009)
        background.stroke()
    } else {
        drawSource(source, in: rect)
    }

    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(bitmap)
    return image
}

func drawSource(_ source: NSImage, in rect: NSRect) {
    source.draw(
        in: rect,
        from: NSRect(origin: .zero, size: source.size),
        operation: .copy,
        fraction: 1.0
    )
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "PlainIcon", code: 1)
    }

    try data.write(to: url, options: [.atomic])
}
