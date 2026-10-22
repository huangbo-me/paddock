import AppKit
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    let background = NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: 924, height: 924), xRadius: 208, yRadius: 208)
    NSGradient(starting: NSColor(calibratedRed: 0.08, green: 0.48, blue: 0.42, alpha: 1), ending: NSColor(calibratedRed: 0.02, green: 0.22, blue: 0.23, alpha: 1))!.draw(in: background, angle: -60)
    let tablet = NSBezierPath(roundedRect: NSRect(x: 212, y: 327, width: 600, height: 400), xRadius: 48, yRadius: 48)
    NSColor(calibratedWhite: 0.97, alpha: 1).setStroke(); tablet.lineWidth = 24; tablet.stroke()
    let line = NSBezierPath(); line.move(to: NSPoint(x: 380, y: 228)); line.line(to: NSPoint(x: 644, y: 228)); line.lineCapStyle = .round; line.lineWidth = 24; line.stroke()
    let plug = NSBezierPath(); plug.move(to: NSPoint(x: 512, y: 327)); plug.line(to: NSPoint(x: 512, y: 228)); plug.lineWidth = 24; plug.lineCapStyle = .round; plug.stroke()
    NSColor(calibratedRed: 0.62, green: 0.93, blue: 0.75, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 658, y: 389, width: 42, height: 42)).fill()
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("icon render failed") }
    let name: String
    if size == 1024 { name = "icon_512x512@2x.png" }
    else if size == 64 { name = "icon_32x32@2x.png" }
    else { name = "icon_\(size)x\(size).png" }
    try png.write(to: folder.appendingPathComponent(name))
    if [32, 256, 512].contains(size) { try png.write(to: folder.appendingPathComponent("icon_\(size/2)x\(size/2)@2x.png")) }
}
