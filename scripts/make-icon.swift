// Generates Resources/AppIcon.icns: white thermometer on an orange-to-red rounded square.
// Usage : swift scripts/make-icon.swift [sortie.icns]
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns"
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let side = CGFloat(pixels)
    rep.size = NSSize(width: side, height: side)
    let scale = side / 1024
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Standard macOS icon grid: 824 pt rounded square centered in a 1024 pt canvas.
    let plate = NSBezierPath(roundedRect: NSRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale),
                             xRadius: 185 * scale, yRadius: 185 * scale)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -10 * scale)
    shadow.set()
    NSColor.black.setFill()
    plate.fill()
    NSGraphicsContext.restoreGraphicsState()

    let orange = NSColor(srgbRed: 1.00, green: 0.66, blue: 0.18, alpha: 1)
    let red = NSColor(srgbRed: 0.90, green: 0.16, blue: 0.20, alpha: 1)
    NSGradient(starting: orange, ending: red)!.draw(in: plate, angle: -90) // orange on top, red at the bottom

    let config = NSImage.SymbolConfiguration(pointSize: 400, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "thermometer.high", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let height = 600 * scale
        let width = height * symbol.size.width / symbol.size.height
        symbol.draw(in: NSRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! render(pixels: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(pixels: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "OK : \(output)" : "iconutil a échoué")
if let preview = CommandLine.arguments.dropFirst(2).first {
    try! render(pixels: 512).write(to: URL(fileURLWithPath: preview))
}
