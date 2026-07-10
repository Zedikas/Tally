import AppKit
import Foundation

struct IconTheme {
    let baseName: String
    let style: String
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let bodyTop: NSColor
    let bodyBottom: NSColor
    let accent: NSColor
    let digit: NSColor
    let screen: NSColor
    let glow: Bool
}

func color(_ hex: Int, _ alpha: CGFloat = 1.0) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255.0,
        green: CGFloat((hex >> 8) & 0xff) / 255.0,
        blue: CGFloat(hex & 0xff) / 255.0,
        alpha: alpha
    )
}

let themes: [IconTheme] = [
    IconTheme(baseName: "TallyIconClassicBlue", style: "blue", backgroundTop: color(0x69B7FF), backgroundBottom: color(0x0052D4), bodyTop: color(0x2EA7FF), bodyBottom: color(0x004BB8), accent: color(0xC8EDFF), digit: .white, screen: color(0x101318), glow: false),
    IconTheme(baseName: "TallyIconNeonDark", style: "dark", backgroundTop: color(0x06101F), backgroundBottom: color(0x000713), bodyTop: color(0x0B1A2E), bodyBottom: color(0x02070F), accent: color(0x1F8CFF), digit: color(0x8FD2FF), screen: color(0x010409), glow: true),
    IconTheme(baseName: "TallyIconGlass", style: "glass", backgroundTop: color(0xEAF7FF), backgroundBottom: color(0x9EC8EC), bodyTop: color(0xF7FDFF, 0.92), bodyBottom: color(0xBDDBF4, 0.86), accent: color(0xFFFFFF, 0.88), digit: color(0xE7F8FF), screen: color(0x31516D), glow: false),
    IconTheme(baseName: "TallyIconPearl", style: "pearl", backgroundTop: color(0xFFFBF2), backgroundBottom: color(0xD9D4CA), bodyTop: color(0xFFFCF6), bodyBottom: color(0xE2DBCF), accent: color(0xFFFFFF), digit: color(0xF7F0E5), screen: color(0x20201E), glow: false),
    IconTheme(baseName: "TallyIconAmber", style: "amber", backgroundTop: color(0xFFBD2E), backgroundBottom: color(0x9A4D00), bodyTop: color(0xFFB51F), bodyBottom: color(0xC16300), accent: color(0xFFE08A), digit: color(0xFFF4D2), screen: color(0x1D1407), glow: false),
    IconTheme(baseName: "TallyIconTechGreen", style: "tech", backgroundTop: color(0x243A20), backgroundBottom: color(0x061206), bodyTop: color(0x222B22), bodyBottom: color(0x090F09), accent: color(0xA8FF12), digit: color(0xB9FF22), screen: color(0x061006), glow: true),
    IconTheme(baseName: "TallyIconCosmicPurple", style: "cosmic", backgroundTop: color(0x9B3DFF), backgroundBottom: color(0x270044), bodyTop: color(0x9A2CFF), bodyBottom: color(0x3A0066), accent: color(0xFF7CFF), digit: .white, screen: color(0x120018), glow: true),
    IconTheme(baseName: "TallyIconSynthwave", style: "synthwave", backgroundTop: color(0xFF38C7), backgroundBottom: color(0x006DFF), bodyTop: color(0x9738FF), bodyBottom: color(0x111A8F), accent: color(0x22E7FF), digit: color(0xFFC8FF), screen: color(0x12001E), glow: true)
]

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconURL = root.appendingPathComponent("Tally/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let alternateIconURL = root.appendingPathComponent("Tally/Resources/AlternateIcons", isDirectory: true)
try FileManager.default.createDirectory(at: appIconURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: alternateIconURL, withIntermediateDirectories: true)

let appIconSizes: [(String, CGFloat)] = [
    ("icon-20x20@2x-iphone.png", 40), ("icon-20x20@3x-iphone.png", 60),
    ("icon-29x29@2x-iphone.png", 58), ("icon-29x29@3x-iphone.png", 87),
    ("icon-40x40@2x-iphone.png", 80), ("icon-40x40@3x-iphone.png", 120),
    ("icon-60x60@2x-iphone.png", 120), ("icon-60x60@3x-iphone.png", 180),
    ("icon-20x20@1x-ipad.png", 20), ("icon-20x20@2x-ipad.png", 40),
    ("icon-29x29@1x-ipad.png", 29), ("icon-29x29@2x-ipad.png", 58),
    ("icon-40x40@1x-ipad.png", 40), ("icon-40x40@2x-ipad.png", 80),
    ("icon-76x76@1x-ipad.png", 76), ("icon-76x76@2x-ipad.png", 152),
    ("icon-83_5x83_5@2x-ipad.png", 167),
    ("icon-1024.png", 1024)
]

for (filename, size) in appIconSizes {
    try savePNG(renderIcon(theme: themes[0], size: size), to: appIconURL.appendingPathComponent(filename))
}

for theme in themes {
    for (suffix, size) in [("", 1024), ("@2x", 120), ("@3x", 180)] as [(String, CGFloat)] {
        try savePNG(renderIcon(theme: theme, size: size), to: alternateIconURL.appendingPathComponent("\(theme.baseName)\(suffix).png"))
    }
}

try appIconContentsJSON.write(to: appIconURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Generated Tally primary AppIcon and alternate icon files.")

func renderIcon(theme: IconTheme, size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    drawBackground(theme: theme, rect: rect, size: size)
    drawCounterDevice(theme: theme, size: size)

    image.unlockFocus()
    return image
}

func drawBackground(theme: IconTheme, rect: NSRect, size: CGFloat) {
    let outer = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.035, dy: size * 0.035), xRadius: size * 0.20, yRadius: size * 0.20)
    NSGradient(colors: [theme.backgroundTop, theme.backgroundBottom])?.draw(in: outer, angle: 90)

    if theme.style == "cosmic" {
        for i in 0..<55 {
            let x = size * CGFloat((i * 37) % 100) / 100.0
            let y = size * CGFloat((i * 61) % 100) / 100.0
            let r = max(1, size * CGFloat((i % 3) + 1) * 0.003)
            NSColor.white.withAlphaComponent(i % 8 == 0 ? 0.9 : 0.35).setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: r, height: r)).fill()
        }
    }

    if theme.style == "glass" || theme.style == "pearl" {
        color(0xFFFFFF, 0.22).setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.10, dy: size * 0.64), xRadius: size * 0.08, yRadius: size * 0.08).fill()
    }

    let border = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.045, dy: size * 0.045), xRadius: size * 0.19, yRadius: size * 0.19)
    (theme.style == "pearl" ? color(0xAEB6C2, 0.45) : theme.accent.withAlphaComponent(theme.glow ? 0.9 : 0.38)).setStroke()
    border.lineWidth = max(1, size * 0.012)
    border.stroke()
}

func drawCounterDevice(theme: IconTheme, size: CGFloat) {
    let bodyRect = NSRect(x: size * 0.335, y: size * 0.17, width: size * 0.33, height: size * 0.66)

    if theme.glow {
        let shadow = NSShadow()
        shadow.shadowColor = theme.accent.withAlphaComponent(0.65)
        shadow.shadowBlurRadius = size * 0.08
        shadow.shadowOffset = .zero
        shadow.set()
    }

    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: size * 0.09, yRadius: size * 0.09)
    NSGradient(colors: [theme.bodyTop, theme.bodyBottom])?.draw(in: bodyPath, angle: 90)
    theme.accent.withAlphaComponent(0.72).setStroke()
    bodyPath.lineWidth = max(1, size * 0.012)
    bodyPath.stroke()

    NSGraphicsContext.restoreGraphicsState()

    let loopPath = NSBezierPath()
    loopPath.appendArc(withCenter: NSPoint(x: size * 0.5, y: size * 0.805), radius: size * 0.055, startAngle: 0, endAngle: 180, clockwise: false)
    theme.accent.withAlphaComponent(0.86).setStroke()
    loopPath.lineWidth = max(2, size * 0.018)
    loopPath.stroke()

    let displayRect = NSRect(x: bodyRect.minX + size * 0.052, y: bodyRect.minY + size * 0.39, width: bodyRect.width - size * 0.104, height: size * 0.15)
    let displayPath = NSBezierPath(roundedRect: displayRect, xRadius: size * 0.026, yRadius: size * 0.026)
    theme.screen.setFill()
    displayPath.fill()
    theme.accent.withAlphaComponent(0.72).setStroke()
    displayPath.lineWidth = max(1, size * 0.006)
    displayPath.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let text = "01" as NSString
    text.draw(
        in: displayRect.insetBy(dx: size * 0.004, dy: size * 0.012),
        withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size * 0.105, weight: .bold),
            .foregroundColor: theme.digit,
            .paragraphStyle: paragraph
        ]
    )

    let buttonRect = NSRect(x: bodyRect.midX - size * 0.085, y: bodyRect.minY + size * 0.14, width: size * 0.17, height: size * 0.17)
    let buttonPath = NSBezierPath(ovalIn: buttonRect)
    NSGradient(colors: [theme.accent.withAlphaComponent(0.95), theme.bodyBottom])?.draw(in: buttonPath, angle: -45)
    theme.accent.withAlphaComponent(0.86).setStroke()
    buttonPath.lineWidth = max(1, size * 0.008)
    buttonPath.stroke()

    color(0xFFFFFF, theme.style == "pearl" || theme.style == "glass" ? 0.32 : 0.18).setFill()
    NSBezierPath(ovalIn: buttonRect.insetBy(dx: size * 0.038, dy: size * 0.045)).fill()
}

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "TallyIconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }
    try data.write(to: url, options: .atomic)
}

let appIconContentsJSON = """
{
  "images" : [
    { "filename" : "icon-20x20@2x-iphone.png", "idiom" : "iphone", "scale" : "2x", "size" : "20x20" },
    { "filename" : "icon-20x20@3x-iphone.png", "idiom" : "iphone", "scale" : "3x", "size" : "20x20" },
    { "filename" : "icon-29x29@2x-iphone.png", "idiom" : "iphone", "scale" : "2x", "size" : "29x29" },
    { "filename" : "icon-29x29@3x-iphone.png", "idiom" : "iphone", "scale" : "3x", "size" : "29x29" },
    { "filename" : "icon-40x40@2x-iphone.png", "idiom" : "iphone", "scale" : "2x", "size" : "40x40" },
    { "filename" : "icon-40x40@3x-iphone.png", "idiom" : "iphone", "scale" : "3x", "size" : "40x40" },
    { "filename" : "icon-60x60@2x-iphone.png", "idiom" : "iphone", "scale" : "2x", "size" : "60x60" },
    { "filename" : "icon-60x60@3x-iphone.png", "idiom" : "iphone", "scale" : "3x", "size" : "60x60" },
    { "filename" : "icon-20x20@1x-ipad.png", "idiom" : "ipad", "scale" : "1x", "size" : "20x20" },
    { "filename" : "icon-20x20@2x-ipad.png", "idiom" : "ipad", "scale" : "2x", "size" : "20x20" },
    { "filename" : "icon-29x29@1x-ipad.png", "idiom" : "ipad", "scale" : "1x", "size" : "29x29" },
    { "filename" : "icon-29x29@2x-ipad.png", "idiom" : "ipad", "scale" : "2x", "size" : "29x29" },
    { "filename" : "icon-40x40@1x-ipad.png", "idiom" : "ipad", "scale" : "1x", "size" : "40x40" },
    { "filename" : "icon-40x40@2x-ipad.png", "idiom" : "ipad", "scale" : "2x", "size" : "40x40" },
    { "filename" : "icon-76x76@1x-ipad.png", "idiom" : "ipad", "scale" : "1x", "size" : "76x76" },
    { "filename" : "icon-76x76@2x-ipad.png", "idiom" : "ipad", "scale" : "2x", "size" : "76x76" },
    { "filename" : "icon-83_5x83_5@2x-ipad.png", "idiom" : "ipad", "scale" : "2x", "size" : "83.5x83.5" },
    { "filename" : "icon-1024.png", "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
