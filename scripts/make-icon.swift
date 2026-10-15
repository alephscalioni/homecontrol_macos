import AppKit

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = CGFloat(size)
    let rect = NSRect(x: scale * 0.07, y: scale * 0.07, width: scale * 0.86, height: scale * 0.86)
    NSColor(red: 0.09, green: 0.10, blue: 0.085, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: scale * 0.20, yRadius: scale * 0.20).fill()
    let configuration = NSImage.SymbolConfiguration(pointSize: scale * 0.47, weight: .light)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(red: 0.77, green: 0.75, blue: 0.65, alpha: 1)]))
    let symbol = NSImage(systemSymbolName: "house.fill", accessibilityDescription: nil)!.withSymbolConfiguration(configuration)!
    let symbolSize = symbol.size
    symbol.draw(in: NSRect(x: (scale - symbolSize.width) / 2, y: (scale - symbolSize.height) / 2, width: symbolSize.width, height: symbolSize.height))
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let png = bitmap.representation(using: .png, properties: [:])!
    let name = size == 1024 ? "icon_512x512@2x.png" : "icon_\(size)x\(size).png"
    try png.write(to: folder.appendingPathComponent(name))
    if [32, 64, 256, 512].contains(size) {
        let half = size / 2
        try png.write(to: folder.appendingPathComponent("icon_\(half)x\(half)@2x.png"))
    }
}
