import SwiftUI
import AppKit
import CoreText

// Generates AppIcon.iconset from a SwiftUI source at every size macOS asks for.
let root = FileManager.default.currentDirectoryPath
let fontsDir = root + "/Resources/Fonts"
for f in (try? FileManager.default.contentsOfDirectory(atPath: fontsDir))?.filter({ $0.hasSuffix(".ttf") }) ?? [] {
    CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: fontsDir + "/" + f) as CFURL, .process, nil)
}

struct Icon: View {
    let side: CGFloat
    var body: some View {
        // macOS icons leave ~10% breathing room inside the canvas.
        let inset = side * 0.095
        let art = side - inset * 2
        ZStack {
            RoundedRectangle(cornerRadius: art * 0.2237, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.16, green: 0.19, blue: 0.34),
                             Color(red: 0.05, green: 0.06, blue: 0.11)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: art, height: art)
                .overlay(
                    RoundedRectangle(cornerRadius: art * 0.2237, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: max(0.5, art * 0.008))
                        .frame(width: art, height: art))
                .shadow(color: .black.opacity(0.35), radius: art * 0.03, y: art * 0.012)

            // Amiri renders U+201C as a true curly quote; the guillemets it
            // draws read as media-player chevrons at icon sizes.
            Text("\u{201C}")
                .font(Font(FontCatalog.font(family: "Amiri", size: art * 1.15)))
                .foregroundStyle(LinearGradient(
                    colors: [Color(red: 0.98, green: 0.86, blue: 0.57),
                             Color(red: 0.80, green: 0.60, blue: 0.26)],
                    startPoint: .top, endPoint: .bottom))
                .offset(y: art * 0.20)
        }
        .frame(width: side, height: side)
    }
}

let outDir = root + "/build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let specs: [(Int, Int)] = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
DispatchQueue.main.async {
    for (pt, scale) in specs {
        let r = ImageRenderer(content: Icon(side: CGFloat(pt)))
        r.scale = CGFloat(scale)
        guard let img = r.nsImage, let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { continue }
        let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
        try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    }
    print("iconset written")
    exit(0)
}
app.run()
