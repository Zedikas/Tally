import AppKit
import Foundation

struct Theme {
    let name: String
    let bg1: Int
    let bg2: Int
    let body1: Int
    let body2: Int
    let accent: Int
    let screen: Int
    let digit: Int
    let glow: Bool
}

func c(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha)
}

let themes = [
    Theme(name: "TallyIconClassicBlue", bg1: 0x69B7FF, bg2: 0x0052D4, body1: 0x2EA7FF, body2: 0x004BB8, accent: 0xC8EDFF, screen: 0x101318, digit: 0xFFFFFF, glow: false),
    Theme(name: "TallyIconNeonDark", bg1: 0x06101F, bg2: 0x000713, body1: 0x0B1A2E, body2: 0x02070F, accent: 0x1F8CFF, screen: 0x010409, digit: 0x8FD2FF, glow: true),
    Theme(name: "TallyIconGlass", bg1: 0xEAF7FF, bg2: 0x9EC8EC, body1: 0xF7FDFF, body2: 0xBDDBF4, accent: 0xFFFFFF, screen: 0x31516D, digit: 0xE7F8FF, glow: false),
    Theme(name: "TallyIconPearl", bg1: 0xFFFBF2, bg2: 0xD9D4CA, body1: 0xFFFCF6, body2: 0xE2DBCF, accent: 0xFFFFFF, screen: 0x20201E, digit: 0xF7F0E5, glow: false),
    Theme(name: "TallyIconAmber", bg1: 0xFFBD2E, bg2: 0x9A4D00, body1: 0xFFB51F, body2: 0xC16300, accent: 0xFFE08A, screen: 0x1D1407, digit: 0xFFF4D2, glow: false),
    Theme(name: "TallyIconTechGreen", bg1: 0x243A20, bg2: 0x061206, body1: 0x222B22, body2: 0x090F09, accent: 0xA8FF12, screen: 0x061006, digit: 0xB9FF22, glow: true),
    Theme(name: "TallyIconCosmicPurple", bg1: 0x9B3DFF, bg2: 0x270044, body1: 0x9A2CFF, body2: 0x3A0066, accent: 0xFF7CFF, screen: 0x120018, digit: 0xFFFFFF, glow: true),
    Theme(name: "TallyIconSynthwave", bg1: 0xFF38C7, bg2: 0x006DFF, body1: 0x9738FF, body2: 0x111A8F, accent: 0x22E7FF, screen: 0x12001E, digit: 0xFFC8FF, glow: true)
]

let contentsJSON = """
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
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

let appIconSizes: [(String, CGFloat)] = [
    ("icon-20x20@2x-iphone.png", 40), ("icon-20x20@3x-iphone.png", 60),
    ("icon-29x29@2x-iphone.png", 58), ("icon-29x29@3x-iphone.png", 87),
    ("icon-40x40@2x-iphone.png", 80), ("icon-40x40@3x-iphone.png", 120),
    ("icon-60x60@2x-iphone.png", 120), ("icon-60x60@3x-iphone.png", 180),
    ("icon-20x20@1x-ipad.png", 20), ("icon-20x20@2x-ipad.png", 40),
    ("icon-29x29@1x-ipad.png", 29), ("icon-29x29@2x-ipad.png", 58),
    ("icon-40x40@1x-ipad.png", 40), ("icon-40x40@2x-ipad.png", 80),
    ("icon-76x76@1x-ipad.png", 76), ("icon-76x76@2x-ipad.png", 152),
    ("icon-83_5x83_5@2x-ipad.png", 167), ("icon-1024.png", 1024)
]

func render(theme: Theme, size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.035, dy: size * 0.035), xRadius: size * 0.20, yRadius: size * 0.20)
    NSGradient(colors: [c(theme.bg1), c(theme.bg2)])?.draw(in: bg, angle: 90)
    c(theme.accent, theme.glow ? 0.86 : 0.42).setStroke()
    bg.lineWidth = max(1, size * 0.014)
    bg.stroke()

    if theme.name.contains("Cosmic") {
        for i in 0..<45 {
            let x = size * CGFloat((i * 37) % 100) / 100
            let y = size * CGFloat((i * 61) % 100) / 100
            NSColor.white.withAlphaComponent(i % 7 == 0 ? 0.9 : 0.35).setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: max(1, size * 0.006), height: max(1, size * 0.006))).fill()
        }
    }

    if theme.name.contains("Glass") || theme.name.contains("Pearl") {
        c(0xFFFFFF, 0.22).setFill()
        let highlight = NSRect(x: size * 0.10, y: size * 0.64, width: size * 0.80, height: size * 0.18)
        NSBezierPath(roundedRect: highlight, xRadius: size * 0.08, yRadius: size * 0.08).fill()
    }

    let body = NSRect(x: size * 0.335, y: size * 0.17, width: size * 0.33, height: size * 0.66)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: size * 0.09, yRadius: size * 0.09)
    NSGradient(colors: [c(theme.body1), c(theme.body2)])?.draw(in: bodyPath, angle: 90)
    c(theme.accent, 0.72).setStroke()
    bodyPath.lineWidth = max(1, size * 0.012)
    bodyPath.stroke()

    let loop = NSBezierPath()
    loop.appendArc(withCenter: NSPoint(x: size * 0.5, y: size * 0.805), radius: size * 0.055, startAngle: 0, endAngle: 180, clockwise: false)
    c(theme.accent, 0.86).setStroke()
    loop.lineWidth = max(2, size * 0.018)
    loop.stroke()

    let display = NSRect(x: body.minX + size * 0.052, y: body.minY + size * 0.39, width: body.width - size * 0.104, height: size * 0.15)
    let displayPath = NSBezierPath(roundedRect: display, xRadius: size * 0.026, yRadius: size * 0.026)
    c(theme.screen).setFill()
    displayPath.fill()
    c(theme.accent, 0.72).setStroke()
    displayPath.lineWidth = max(1, size * 0.006)
    displayPath.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    ("01" as NSString).draw(in: display.insetBy(dx: size * 0.004, dy: size * 0.012), withAttributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: size * 0.105, weight: .bold),
        .foregroundColor: c(theme.digit),
        .paragraphStyle: paragraph
    ])

    let buttonRect = NSRect(x: body.midX - size * 0.085, y: body.minY + size * 0.14, width: size * 0.17, height: size * 0.17)
    let buttonPath = NSBezierPath(ovalIn: buttonRect)
    NSGradient(colors: [c(theme.accent, 0.95), c(theme.body2)])?.draw(in: buttonPath, angle: -45)
    c(theme.accent, 0.86).setStroke()
    buttonPath.lineWidth = max(1, size * 0.008)
    buttonPath.stroke()
    c(0xFFFFFF, theme.name.contains("Pearl") || theme.name.contains("Glass") ? 0.32 : 0.18).setFill()
    NSBezierPath(ovalIn: buttonRect.insetBy(dx: size * 0.038, dy: size * 0.045)).fill()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "TallyIconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }
    try data.write(to: url, options: .atomic)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconDir = root.appendingPathComponent("Tally/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let altDir = root.appendingPathComponent("Tally/Resources/AlternateIcons", isDirectory: true)
try FileManager.default.createDirectory(at: appIconDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: altDir, withIntermediateDirectories: true)

for (filename, size) in appIconSizes {
    let url = appIconDir.appendingPathComponent(filename)
    try savePNG(render(theme: themes[0], size: size), to: url)
    print("Generated \(url.path)")
}

for theme in themes {
    for (suffix, size) in [("", CGFloat(1024)), ("@2x", CGFloat(120)), ("@3x", CGFloat(180))] {
        let url = altDir.appendingPathComponent("\(theme.name)\(suffix).png")
        try savePNG(render(theme: theme, size: size), to: url)
        print("Generated \(url.path)")
    }
}

try contentsJSON.write(to: appIconDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Generated Tally app icon assets and alternate icons")
