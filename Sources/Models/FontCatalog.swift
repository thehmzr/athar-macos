import AppKit

/// Calligraphic school an Arabic face belongs to.
enum ArabicScript: String, Codable, CaseIterable {
    case naskh, kufic, ruqaa, nastaliq, diwani, modern, display

    var displayName: String {
        switch self {
        case .naskh:    return "Naskh — نسخ"
        case .kufic:    return "Kufic — كوفي"
        case .ruqaa:    return "Ruq'ah — رقعة"
        case .nastaliq: return "Nasta'liq — نستعليق"
        case .diwani:   return "Diwani — ديواني"
        case .modern:   return "Modern — حديث"
        case .display:  return "Display — عرض"
        }
    }
}

struct FontChoice: Identifiable, Hashable {
    /// Family name — resolved through NSFontDescriptor so variable fonts work.
    let family: String
    let label: String
    let script: ArabicScript?
    /// Desired *total* line height as a multiple of point size.
    ///
    /// Arabic faces differ wildly in intrinsic metrics — Gulzar's natural line
    /// height is 2.70x its point size while Jomhuria's is 1.00x. Extra leading
    /// is therefore computed as the difference between this target and the
    /// face's real metrics, never added blindly, or Nastaliq double-counts and
    /// falls apart.
    let lineHeightTarget: CGFloat
    /// Some calligraphic faces run visually small at a given point size.
    let opticalScale: CGFloat

    var id: String { family }

    init(_ family: String, _ label: String, script: ArabicScript? = nil,
         lineHeightTarget: CGFloat = 1.40, opticalScale: CGFloat = 1.0) {
        self.family = family; self.label = label; self.script = script
        self.lineHeightTarget = lineHeightTarget; self.opticalScale = opticalScale
    }
}

enum FontCatalog {

    /// Bundled Arabic faces, grouped by calligraphic school.
    ///
    /// Targets are calibrated against each face's measured natural line height
    /// so Arabic diacritics clear the line above without stranding the text.
    static let arabic: [FontChoice] = [
        // Naskh — the classical book hand
        FontChoice("Amiri", "Amiri", script: .naskh, lineHeightTarget: 1.88, opticalScale: 1.10),
        FontChoice("Scheherazade New", "Scheherazade New", script: .naskh, lineHeightTarget: 2.08, opticalScale: 1.18),
        FontChoice("Lateef", "Lateef", script: .naskh, lineHeightTarget: 1.78, opticalScale: 1.22),
        FontChoice("Noto Naskh Arabic", "Noto Naskh", script: .naskh, lineHeightTarget: 1.82),
        FontChoice("Harmattan", "Harmattan", script: .naskh, lineHeightTarget: 1.82, opticalScale: 1.10),
        FontChoice("Markazi Text", "Markazi Text", script: .naskh, lineHeightTarget: 1.68, opticalScale: 1.12),

        // Kufic — angular, geometric
        FontChoice("Reem Kufi", "Reem Kufi", script: .kufic, lineHeightTarget: 1.72),
        FontChoice("Noto Kufi Arabic", "Noto Kufi", script: .kufic, lineHeightTarget: 1.96),
        FontChoice("Qahiri", "Qahiri", script: .kufic, lineHeightTarget: 1.62, opticalScale: 1.05),

        // Ruq'ah — the everyday handwriting hand
        FontChoice("Aref Ruqaa", "Aref Ruqaa", script: .ruqaa, lineHeightTarget: 1.88, opticalScale: 1.08),

        // Nasta'liq — hanging script; metrics are already enormous, so the
        // target sits just above natural and adds almost nothing.
        FontChoice("Noto Nastaliq Urdu", "Noto Nastaliq", script: .nastaliq, lineHeightTarget: 2.56, opticalScale: 0.92),
        FontChoice("Gulzar", "Gulzar", script: .nastaliq, lineHeightTarget: 2.74, opticalScale: 0.95),
        FontChoice("Mirza", "Mirza", script: .nastaliq, lineHeightTarget: 1.78, opticalScale: 1.10),

        // Display / decorative
        FontChoice("Katibeh", "Katibeh", script: .display, lineHeightTarget: 1.72, opticalScale: 1.25),
        FontChoice("Rakkas", "Rakkas", script: .display, lineHeightTarget: 1.72, opticalScale: 1.05),
        FontChoice("Jomhuria", "Jomhuria", script: .display, lineHeightTarget: 1.48, opticalScale: 1.32),
        FontChoice("Lalezar", "Lalezar", script: .display, lineHeightTarget: 1.72),
        FontChoice("Marhey", "Marhey", script: .display, lineHeightTarget: 1.82),
        FontChoice("Vibes", "Vibes", script: .display, lineHeightTarget: 1.86, opticalScale: 1.15),

        // Modern sans — clean UI-grade Arabic
        FontChoice("Cairo", "Cairo", script: .modern, lineHeightTarget: 1.90),
        FontChoice("Tajawal", "Tajawal", script: .modern, lineHeightTarget: 1.66),
        FontChoice("Almarai", "Almarai", script: .modern, lineHeightTarget: 1.62),
        FontChoice("Changa", "Changa", script: .modern, lineHeightTarget: 1.90),
        FontChoice("El Messiri", "El Messiri", script: .modern, lineHeightTarget: 1.74),
    ]

    /// The San Francisco family and New York are system faces that are not
    /// addressable by family name at all — `NSFontDescriptor(family: "New York")`
    /// returns nil. They are only reachable through a system *design*, so they
    /// get sentinel identifiers resolved separately in `font(family:size:)`.
    static let systemFamilySentinel = "__system__"
    static let serifSentinel = "__serif__"
    static let roundedSentinel = "__rounded__"
    static let monoSentinel = "__mono__"

    static func systemDesign(for family: String) -> NSFontDescriptor.SystemDesign? {
        switch family {
        case systemFamilySentinel: return .default
        case serifSentinel:        return .serif
        case roundedSentinel:      return .rounded
        case monoSentinel:         return .monospaced
        default:                   return nil
        }
    }

    /// Latin faces — the four system designs, plus installed families that
    /// suit quotes.
    ///
    /// Availability is tested by actually resolving a descriptor rather than by
    /// consulting `availableFontFamilies`, which omits genuinely usable faces
    /// (Iowan Old Style resolves fine but is absent from that list).
    static let latin: [FontChoice] = {
        let designs = [
            FontChoice(systemFamilySentinel, "System", lineHeightTarget: 1.42),
            FontChoice(serifSentinel, "New York", lineHeightTarget: 1.45),
            FontChoice(roundedSentinel, "SF Rounded", lineHeightTarget: 1.42),
            FontChoice(monoSentinel, "SF Mono", lineHeightTarget: 1.45),
        ]
        let preferred = [
            "Georgia", "Palatino", "Baskerville", "Didot", "Optima", "Futura",
            "Avenir Next", "Helvetica Neue", "Iowan Old Style", "Charter", "Cochin",
            "Hoefler Text", "Menlo", "Snell Roundhand", "Zapfino", "Papyrus",
            "Times New Roman",
        ]
        let installed = preferred.filter { fam in
            let d = NSFontDescriptor(fontAttributes: [.family: fam])
            return NSFont(descriptor: d, size: 12)?.familyName == fam
        }.map { FontChoice($0, $0, lineHeightTarget: 1.45) }
        return designs + installed
    }()

    static func byFamily(_ family: String) -> FontChoice? {
        arabic.first { $0.family == family } ?? latin.first { $0.family == family }
    }

    static func arabicGrouped() -> [(ArabicScript, [FontChoice])] {
        ArabicScript.allCases.compactMap { s in
            let items = arabic.filter { $0.script == s }
            return items.isEmpty ? nil : (s, items)
        }
    }

    /// Resolve a family name to a concrete NSFont. Uses a font *descriptor* so
    /// variable fonts (Cairo, Reem Kufi, Noto…) resolve to their default
    /// instance rather than failing on an odd PostScript name.
    static func font(family: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        if family.isEmpty { return NSFont.systemFont(ofSize: size, weight: weight) }

        // System designs (SF Pro, New York, SF Rounded, SF Mono) are only
        // reachable by applying a design to the system font.
        if let design = systemDesign(for: family) {
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            guard design != .default else { return base }
            if let d = base.fontDescriptor.withDesign(design),
               let f = NSFont(descriptor: d, size: size) { return f }
            return base
        }

        var traits: [NSFontDescriptor.TraitKey: Any] = [.weight: weight]
        if weight == .regular { traits = [:] }
        let desc = NSFontDescriptor(fontAttributes: [.family: family, .traits: traits])
        if let f = NSFont(descriptor: desc, size: size) { return f }
        if let f = NSFont(name: family, size: size) { return f }
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    /// A font's natural line height as a multiple of its point size.
    static func naturalLineHeightRatio(_ font: NSFont) -> CGFloat {
        guard font.pointSize > 0 else { return 1.2 }
        return (font.ascender - font.descender + font.leading) / font.pointSize
    }

    /// Extra leading needed to reach `target`, never negative — AppKit cannot
    /// tighten below a face's intrinsic line height via `lineSpacing`.
    static func extraLineSpacing(font: NSFont, target: CGFloat,
                                 userScale: CGFloat = 1.0) -> CGFloat {
        let natural = naturalLineHeightRatio(font)
        return font.pointSize * max(0, (target - natural)) * userScale
    }

    /// Registers every .ttf in Resources/Fonts. `ATSApplicationFontsPath` in
    /// Info.plist normally handles this, but registering explicitly makes the
    /// faces available when running the binary outside a bundle too.
    static func registerBundledFonts() {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
              let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil) else { return }
        for url in files where url.pathExtension.lowercased() == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
