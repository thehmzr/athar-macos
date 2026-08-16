import SwiftUI
import AppKit
import CoreText

/// Offscreen render harness. Builds the real QuoteWidgetView at several sizes
/// and writes PNGs so typography can be checked without a screen capture.
enum RenderHarness {

    static func registerFonts(_ dir: String) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
        for f in files where f.hasSuffix(".ttf") {
            let url = URL(fileURLWithPath: dir + "/" + f)
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    @MainActor
    static func write<V: View>(_ view: V, size: CGSize, to path: String) {
        let r = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        r.scale = 2
        guard let img = r.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("FAILED to render \(path)"); return
        }
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)  \(Int(size.width))x\(Int(size.height))")
    }

    /// One specimen row per bundled Arabic face, rendered in that face.
    struct Specimen: View {
        let sample = "العِلمُ نورٌ وَالجَهلُ ظَلام"
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(FontCatalog.arabicGrouped(), id: \.0) { script, fonts in
                    Text(script.displayName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 14).padding(.bottom, 4).padding(.horizontal, 18)
                    ForEach(fonts) { f in
                        HStack(spacing: 14) {
                            Text(f.label)
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 110, alignment: .leading)
                            Text(sample)
                                .font(Font(FontCatalog.font(family: f.family, size: 26)))
                                .foregroundStyle(.white)
                                .environment(\.layoutDirection, .rightToLeft)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .frame(height: 26 * f.lineHeightTarget + 10)
                        .padding(.horizontal, 18)
                    }
                }
            }
            .padding(.vertical, 10)
            .background(Color(red: 0.07, green: 0.08, blue: 0.11))
        }
    }
}
