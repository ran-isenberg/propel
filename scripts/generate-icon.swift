#!/usr/bin/env swift

import AppKit
import CoreGraphics

/// Generate a Propel app icon: a rounded-rect with gradient background and a rocket symbol.
func generateIcon(size: Int) -> NSImage {
    let cgSize = CGSize(width: size, height: size)
    let image = NSImage(size: cgSize)

    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(origin: .zero, size: cgSize)
    let s = CGFloat(size)

    // Background: rounded rect with gradient
    let cornerRadius = s * 0.22
    let bgPath = CGPath(roundedRect: rect.insetBy(dx: s * 0.02, dy: s * 0.02),
                        cornerWidth: cornerRadius, cornerHeight: cornerRadius,
                        transform: nil)

    context.saveGState()
    context.addPath(bgPath)
    context.clip()

    // Dark gradient: deep navy to dark purple
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.08, green: 0.08, blue: 0.20, alpha: 1.0),
        CGColor(red: 0.15, green: 0.10, blue: 0.35, alpha: 1.0),
        CGColor(red: 0.20, green: 0.12, blue: 0.45, alpha: 1.0),
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.6, 1.0]

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations) {
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: s),
                                   end: CGPoint(x: s, y: 0),
                                   options: [])
    }
    context.restoreGState()

    // Subtle border
    context.saveGState()
    context.setStrokeColor(CGColor(red: 0.4, green: 0.3, blue: 0.7, alpha: 0.3))
    context.setLineWidth(s * 0.01)
    context.addPath(bgPath)
    context.strokePath()
    context.restoreGState()

    // Draw 4 kanban columns as subtle background elements
    let colWidth = s * 0.14
    let colHeight = s * 0.35
    let colY = s * 0.52
    let colSpacing = s * 0.04
    let totalWidth = 4 * colWidth + 3 * colSpacing
    let startX = (s - totalWidth) / 2

    for i in 0..<4 {
        let x = startX + CGFloat(i) * (colWidth + colSpacing)
        let colRect = CGRect(x: x, y: colY, width: colWidth, height: colHeight)
        let colPath = CGPath(roundedRect: colRect, cornerWidth: s * 0.02, cornerHeight: s * 0.02, transform: nil)
        context.saveGState()
        context.addPath(colPath)
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.06))
        context.fillPath()
        context.restoreGState()

        // Small card dots in columns (varying heights to look like a board)
        let cardCounts = [3, 2, 1, 2]
        let dotSize = s * 0.08
        for j in 0..<cardCounts[i] {
            let dotX = x + (colWidth - dotSize) / 2
            let dotY = colY + colHeight - s * 0.05 - CGFloat(j) * (dotSize + s * 0.03)
            let dotRect = CGRect(x: dotX, y: dotY - dotSize, width: dotSize, height: dotSize * 0.6)
            let dotPath = CGPath(roundedRect: dotRect, cornerWidth: s * 0.01, cornerHeight: s * 0.01, transform: nil)
            let colors: [CGColor] = [
                CGColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.5),   // blue
                CGColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 0.5),   // purple
                CGColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.5),   // red
                CGColor(red: 0.2, green: 0.8, blue: 0.5, alpha: 0.5),   // green
            ]
            context.saveGState()
            context.addPath(dotPath)
            context.setFillColor(colors[i])
            context.fillPath()
            context.restoreGState()
        }
    }

    // Draw "P" letter - bold, modern
    let fontSize = s * 0.38
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(red: 0.85, green: 0.85, blue: 1.0, alpha: 1.0),
    ]
    let text = "P" as NSString
    let textSize = text.size(withAttributes: attributes)
    let textOrigin = CGPoint(
        x: (s - textSize.width) / 2,
        y: s * 0.08
    )
    text.draw(at: textOrigin, withAttributes: attributes)

    // Small rocket accent (using triangle + flame shape)
    let rocketCenterX = s * 0.72
    let rocketCenterY = s * 0.28

    // Rocket body (small triangle pointing up-right)
    let rocketPath = CGMutablePath()
    let rSize = s * 0.08
    rocketPath.move(to: CGPoint(x: rocketCenterX + rSize, y: rocketCenterY + rSize))
    rocketPath.addLine(to: CGPoint(x: rocketCenterX - rSize * 0.3, y: rocketCenterY + rSize * 0.3))
    rocketPath.addLine(to: CGPoint(x: rocketCenterX + rSize * 0.3, y: rocketCenterY - rSize * 0.3))
    rocketPath.closeSubpath()

    context.saveGState()
    context.addPath(rocketPath)
    context.setFillColor(CGColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 0.9))
    context.fillPath()
    context.restoreGState()

    image.unlockFocus()
    return image
}

func createICNS(at path: String) {
    let sizes = [16, 32, 64, 128, 256, 512, 1024]
    let iconsetPath = "/tmp/Propel.iconset"

    // Create iconset directory
    try? FileManager.default.removeItem(atPath: iconsetPath)
    try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

    for size in sizes {
        let image = generateIcon(size: size)

        // Save @1x
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let name: String
            if size == 1024 {
                name = "icon_512x512@2x.png"
            } else {
                name = "icon_\(size)x\(size).png"
            }
            try! pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name)"))
        }

        // Save @2x (half the name)
        if size <= 512 && size >= 32 {
            let halfSize = size / 2
            let name = "icon_\(halfSize)x\(halfSize)@2x.png"
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try! pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name)"))
            }
        }
    }

    // Convert iconset to icns
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetPath, "-o", path]
    try! process.run()
    process.waitUntilExit()

    // Cleanup
    try? FileManager.default.removeItem(atPath: iconsetPath)

    if process.terminationStatus == 0 {
        print("Icon created at: \(path)")
    } else {
        print("Failed to create icon")
    }
}

// Generate the icon
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Sources/Propel/Resources/AppIcon.icns"

createICNS(at: outputPath)
