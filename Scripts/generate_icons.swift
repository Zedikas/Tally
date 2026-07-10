import AppKit
import Foundation

struct IconVariant {
    let fileBase: String
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let deviceTop: NSColor
    let deviceBottom: NSColor
    let accent: NSColor
    let digit: NSColor
    let screen: NSColor
    let glow: Bool
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xff) / 255
        let g = CGFloat((hex >> 8) & 0xff) / 255
        let b = CGFloat(hex & 0xff) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetRoot = root.appendingPathComponent("Tally/Resources/Assets.xcassets/AppIcon.appiconset")
let altRoot = root.appendingPathComponent("Tally/Resources/AlternateIcons")
try FileManager.default.createDirectory(at: assetRoot, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: altRoot, withIntermediateDirectories: true)

let variants: [IconVariant] = [
    IconVariant(fileBase: "TallyIconClassicBlue", backgroundTop: NSColor(hex: 0x69b7ff), backgroundBottom: NSColor(hex: 0x0052d4), deviceTop: NSColor(hex: 0x2ea7ff), deviceBottom: NSColor(hex: 0x004bb8), accent: NSColor(hex: 0x8fd2ff), digit: .white, screen: NSColor(hex: 0x101318), glow: false),
    IconVariant(fileBase: "TallyIconNeonDark", backgroundTop: NSColor(hex: 0x06101f), backgroundBottom: NSColor(hex: 0x000713), deviceTop: NSColor(hex: 0x0b1a2e), deviceBottom: NSColor(hex: 0x02070f), accent: NSColor(hex: 0x1f8cff), digit: NSColor(hex: 0x8fd2ff), screen: NSColor(hex: 0x010409), glow: true),
    IconVariant(fileBase: "TallyIconGlass", backgroundTop: NSColor(hex: 0xeaf7ff), backgroundBottom: NSColor(hex: 0x9ec8ec), deviceTop: NSColor(hex: 0xf7fdff, alpha: 0.92), deviceBottom: NSColor(hex: 0xbddbf4, alpha: 0.86), accent: NSColor(hex: 0xdaf4ff), digit: NSColor(hex: 0xdff5ff), screen: NSColor(hex: 0x31516d), glow: false),
    IconVariant(fileBase: "TallyIconPearl", backgroundTop: NSColor(hex: 0xfffbf2), backgroundBottom: NSColor(hex: 0xd9d4ca), deviceTop: NSColor(hex: 0xfffcf6), deviceBottom: NSColor(hex: 0xe2dbcf), accent: NSColor(hex: 0xffffff), digit: NSColor(hex: 0xf7f0e5), screen: NSColor(hex: 0x20201e), glow: false),
    IconVariant(fileBase: "TallyIconAmber", backgroundTop: NSColor(hex: 0xffbd2e), backgroundBottom: NSColor(hex: 0x9a4d00), deviceTop: NSColor(hex: 0xffb51f), deviceBottom: NSColor(hex: 0xc16300), accent: NSColor(hex: 0xffe08a), digit: NSColor(hex: 0xfff4d2), screen: NSColor(hex: 0x1d1407), glow: false),
    IconVariant(fileBase: "TallyIconTechGreen", backgroundTop: NSColor(hex: 0x243a20), backgroundBottom: NSColor(hex: 0x061206), deviceTop: NSColor(hex: 0x222b22), deviceBottom: NSColor(hex: 0x090f09), accent: NSColor(hex: 0xa8ff12), digit: NSColor(hex: 0xb9ff22), screen: NSColor(hex: 0x061006), glow: true),
    IconVariant(fileBase: "TallyIconCosmicPurple", backgroundTop: NSColor(hex: 0x9b3dff), backgroundBottom: NSColor(hex: 0x270044), deviceTop: NSColor(hex: 0x9a2cff), deviceBottom: NSColor(hex: 0x3a0066), accent: NSColor(hex: 0xff7cff), digit: .white, screen: NSColor(hex: 0x120018), glow: true),
    IconVariant(fileBase: "TallyIconSynthwave", backgroundTop: NSColor(hex: 0xff38c7), backgroundBottom: NSColor(hex: 0x006dff), deviceTop: NSColor(hex: 0x9738ff), deviceBottom: NSColor(hex: 0x111a8f), accent: NSColor(hex: 0x22e7ff), digit: NSColor(hex: 0xffc8ff), screen: NSColor(hex: 0x12001e), glow: true)
]

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fill(_ rect: NSRect, radius: CGFloat, top: NSColor, bottom: NSColor) {
    let path = roundedRect(rect, radius: radius)
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGradient(starting: top, ending: bottom)?.draw(in: rect, angle: 90)
    NSGraphicsContext.restoreGraphicsState()
}

func savePNG(image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "TallyIconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try data.write(to: url, options: .atomic)
}

func drawIcon(size: CGFloat, variant: IconVariant, to url: URL) throws {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let outer = canvas.insetBy(dx: size * 0.035, dy: size * 0.035)
    fill(outer, radius: size * 0.18, top: variant.backgroundTop, bottom: variant.backgroundBottom)
    variant.accent.withAlphaComponent(variant.glow ? 0.9 : 0.55).setStroke()
    let outerPath = roundedRect(outer.insetBy(dx: size * 0.012, dy: size * 0.012), radius: size * 0.17)
    outerPath.lineWidth = size * 0.014
    outerPath.stroke()

    if variant.glow {
        variant.accent.withAlphaComponent(0.24).setStroke()
        let glowPath = roundedRect(outer.insetBy(dx: size * 0.025, dy: size * 0.025), radius: size * 0.16)
        glowPath.lineWidth = size * 0.035
        glowPath.stroke()
    }

    let device = NSRect(x: size * 0.34, y: size * 0.17, width: size * 0.32, height: size * 0.66)
    fill(device, radius: size * 0.09, top: variant.deviceTop, bottom: variant.deviceBottom)
    variant.accent.withAlphaComponent(0.7).setStroke()
    let devicePath = roundedRect(device.insetBy(dx: size * 0.006, dy: size * 0.006), radius: size * 0.085)
    devicePath.lineWidth = size * 0.012
    devicePath.stroke()

    let loop = NSRect(x: size * 0.445, y: size * 0.79, width: size * 0.11, height: size * 0.11)
    let loopPath = NSBezierPath()
    loopPath.appendArc(withCenter: NSPoint(x: loop.midX, y: loop.minY), radius: loop.width / 2, startAngle: 0, endAngle: 180, clockwise: false)
    variant.accent.withAlphaComponent(0.85).setStroke()
    loopPath.lineWidth = size * 0.018
    loopPath.stroke()

    let display = NSRect(x: device.minX + size * 0.052, y: device.minY + size * 0.38, width: device.width - size * 0.104, height: size * 0.15)
    roundedRect(display, radius: size * 0.026).setFillColor(variant.screen)
    roundedRect(display, radius: size * 0.026).fill()
    variant.accent.withAlphaComponent(0.75).setStroke()
    let displayStroke = roundedRect(display.insetBy(dx: -size * 0.004, dy: -size * 0.004), radius: size * 0.03)
    displayStroke.lineWidth = size * 0.006
    displayStroke.stroke()

    let text = "01" as NSString
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let font = NSFont.monospacedDigitSystemFont(ofSize: size * 0.105, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: variant.digit,
        .paragraphStyle: paragraph
    ]
    text.draw(in: display.insetBy(dx: size * 0.005, dy: size * 0.012), withAttributes: attributes)

    let buttonRect = NSRect(x: device.midX - size * 0.085, y: device.minY + size * 0.14, width: size * 0.17, height: size * 0.17)
    NSGradient(starting: variant.accent.withAlphaComponent(0.95), ending: variant.deviceBottom)?.draw(in: NSBezierPath(ovalIn: buttonRect), angle: -45)
    variant.accent.withAlphaComponent(0.85).setStroke()
    let buttonStroke = NSBezierPath(ovalIn: buttonRect.insetBy(dx: -size * 0.008, dy: -size * 0.008))
    buttonStroke.lineWidth = size * 0.009
    buttonStroke.stroke()

    try savePNG(image: image, to: url)
}

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

let primary = variants[0]
for (filename, size) in appIconSizes {
    try drawIcon(size: size, variant: primary, to: assetRoot.appendingPathComponent(filename))
}

for variant in variants {
    try drawIcon(size: 1024, variant: variant, to: altRoot.appendingPathComponent("\(variant.fileBase).png"))
}

let contents = """
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
try contents.write(to: assetRoot.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

print("Generated Tally primary and alternate app icons.")
