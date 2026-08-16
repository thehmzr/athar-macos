import SwiftUI

/// Codable RGBA so themes can round-trip through JSON.
struct RGBA: Codable, Hashable {
    var r: Double, g: Double, b: Double, a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }

    init(_ ns: NSColor) {
        let c = ns.usingColorSpace(.sRGB) ?? .white
        self.init(Double(c.redComponent), Double(c.greenComponent),
                  Double(c.blueComponent), Double(c.alphaComponent))
    }

    func withAlpha(_ a: Double) -> RGBA { RGBA(r, g, b, a) }

    /// The same colour re-pitched for the opposite background brightness.
    ///
    /// Hue, saturation and alpha are kept so a tinted palette stays tinted;
    /// only brightness flips. Used to derive a Light Mode counterpart when the
    /// user has not chosen one explicitly.
    var flippedBrightness: RGBA {
        let ns = nsColor.usingColorSpace(.sRGB) ?? .white
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        // Land on a definite ink or a definite paper rather than mirroring
        // exactly, which would leave mid-tones illegible on both sides.
        let nb: CGFloat = b > 0.5 ? 0.14 : 0.96
        return RGBA(NSColor(hue: h, saturation: s * 0.85, brightness: nb, alpha: a))
    }

    static let white = RGBA(1, 1, 1)
    static let black = RGBA(0, 0, 0)

    /// Relative luminance — used to auto-pick readable text on a background.
    var luminance: Double {
        func lin(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }
}

enum BackgroundStyle: String, Codable, CaseIterable {
    case solid, gradient, glass, image

    var displayName: String {
        switch self {
        case .solid:    return "Solid"
        case .gradient: return "Gradient"
        case .glass:    return "Glass"
        case .image:    return "Image"
        }
    }
}

enum GlassMaterial: String, Codable, CaseIterable {
    case ultraThin, thin, regular, thick, hud

    var displayName: String {
        switch self {
        case .ultraThin: return "Ultra Thin"
        case .thin:      return "Thin"
        case .regular:   return "Regular"
        case .thick:     return "Thick"
        case .hud:       return "HUD"
        }
    }

    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .ultraThin: return .popover
        case .thin:      return .menu
        case .regular:   return .sidebar
        case .thick:     return .underWindowBackground
        case .hud:       return .hudWindow
        }
    }
}

/// A complete visual look for a widget panel.
struct Theme: Codable, Hashable {
    /// Declared explicitly because the lenient `init(from:)` in Settings.swift
    /// suppresses synthesis of these keys.
    enum CodingKeys: String, CodingKey {
        case name, background, solidColor, gradientTop, gradientBottom, gradientAngle
        case glassMaterial, imageBookmark, imageOpacity, imageBlur
        case textColor, authorColor, accentColor, translationColor
        case glassFollowsSystem, lightTextColor, lightAuthorColor
        case lightTranslationColor, lightBorderColor
        case cornerRadius, padding, backgroundOpacity
        case shadowEnabled, shadowRadius, shadowOpacity
        case borderEnabled, borderColor, borderWidth
    }

    var name: String = "Custom"

    var background: BackgroundStyle = .gradient
    var solidColor: RGBA = RGBA(0.08, 0.09, 0.12)
    var gradientTop: RGBA = RGBA(0.16, 0.18, 0.30)
    var gradientBottom: RGBA = RGBA(0.06, 0.07, 0.12)
    var gradientAngle: Double = 135
    var glassMaterial: GlassMaterial = .regular
    /// Security-scoped bookmark to a user-chosen background image.
    var imageBookmark: Data? = nil
    var imageOpacity: Double = 0.55
    var imageBlur: Double = 0

    var textColor: RGBA = RGBA(0.97, 0.97, 0.98)
    var authorColor: RGBA = RGBA(0.97, 0.97, 0.98, 0.62)
    var accentColor: RGBA = RGBA(0.55, 0.72, 1.0)
    /// Colour for the English gloss. Nil means "derive from the attribution
    /// colour", so existing themes and presets keep working untouched.
    var translationColor: RGBA? = nil

    // MARK: - Light Mode palette (glass only)

    /// When the glass material follows the system, the *text* has to follow it
    /// too. A fixed light palette over a Light Mode material is the white-on-
    /// white bug this whole mechanism exists to avoid.
    var glassFollowsSystem: Bool = true
    /// Explicit Light Mode colours; nil derives them from the dark ones.
    var lightTextColor: RGBA? = nil
    var lightAuthorColor: RGBA? = nil
    var lightTranslationColor: RGBA? = nil
    var lightBorderColor: RGBA? = nil

    /// Whether this theme should swap palettes with the system appearance.
    var adaptsToAppearance: Bool { background == .glass && glassFollowsSystem }

    /// The palette to draw with, given the current system appearance.
    /// Non-adaptive themes always return their configured colours.
    func palette(darkAppearance: Bool) -> (text: RGBA, author: RGBA,
                                           translation: RGBA?, border: RGBA) {
        guard adaptsToAppearance, !darkAppearance else {
            return (textColor, authorColor, translationColor, borderColor)
        }
        return (lightTextColor      ?? textColor.flippedBrightness,
                lightAuthorColor    ?? authorColor.flippedBrightness,
                lightTranslationColor ?? translationColor?.flippedBrightness,
                lightBorderColor    ?? RGBA(0, 0, 0, borderColor.a))
    }

    var cornerRadius: Double = 20
    var padding: Double = 26
    var backgroundOpacity: Double = 1.0

    var shadowEnabled: Bool = true
    var shadowRadius: Double = 22
    var shadowOpacity: Double = 0.32

    var borderEnabled: Bool = true
    var borderColor: RGBA = RGBA(1, 1, 1, 0.12)
    var borderWidth: Double = 1

    var gradientStartPoint: UnitPoint {
        let rad = gradientAngle * .pi / 180
        return UnitPoint(x: 0.5 - cos(rad) * 0.5, y: 0.5 - sin(rad) * 0.5)
    }
    var gradientEndPoint: UnitPoint {
        let rad = gradientAngle * .pi / 180
        return UnitPoint(x: 0.5 + cos(rad) * 0.5, y: 0.5 + sin(rad) * 0.5)
    }
}

extension Theme {
    /// Built-in looks. All unlocked.
    static let presets: [Theme] = [
        {
            var t = Theme(); t.name = "Midnight"
            t.background = .gradient
            t.gradientTop = RGBA(0.11, 0.13, 0.24); t.gradientBottom = RGBA(0.03, 0.04, 0.08)
            t.accentColor = RGBA(0.51, 0.68, 1.0)
            return t
        }(),
        {
            var t = Theme(); t.name = "Parchment"
            t.background = .gradient
            t.gradientTop = RGBA(0.98, 0.95, 0.88); t.gradientBottom = RGBA(0.93, 0.88, 0.78)
            t.textColor = RGBA(0.18, 0.15, 0.11)
            t.authorColor = RGBA(0.18, 0.15, 0.11, 0.62)
            t.accentColor = RGBA(0.55, 0.38, 0.15)
            t.borderColor = RGBA(0, 0, 0, 0.10)
            return t
        }(),
        {
            var t = Theme(); t.name = "Ink"
            t.background = .solid
            t.solidColor = RGBA(0.05, 0.05, 0.06)
            t.accentColor = RGBA(0.85, 0.78, 0.55)
            t.borderColor = RGBA(1, 1, 1, 0.10)
            return t
        }(),
        {
            var t = Theme(); t.name = "Desert"
            t.background = .gradient
            t.gradientTop = RGBA(0.96, 0.72, 0.42); t.gradientBottom = RGBA(0.72, 0.35, 0.24)
            t.textColor = RGBA(1, 0.99, 0.96)
            t.authorColor = RGBA(1, 0.99, 0.96, 0.70)
            t.accentColor = RGBA(0.35, 0.16, 0.10)
            return t
        }(),
        {
            var t = Theme(); t.name = "Sea"
            t.background = .gradient
            t.gradientTop = RGBA(0.20, 0.55, 0.62); t.gradientBottom = RGBA(0.06, 0.20, 0.31)
            t.accentColor = RGBA(0.62, 0.90, 0.88)
            return t
        }(),
        {
            var t = Theme(); t.name = "Rose"
            t.background = .gradient
            t.gradientTop = RGBA(0.98, 0.72, 0.76); t.gradientBottom = RGBA(0.60, 0.31, 0.52)
            t.textColor = RGBA(1, 0.98, 0.99)
            t.authorColor = RGBA(1, 0.98, 0.99, 0.70)
            t.accentColor = RGBA(0.42, 0.13, 0.28)
            return t
        }(),
        {
            var t = Theme(); t.name = "Glass"
            t.background = .glass
            t.glassMaterial = .regular
            t.textColor = RGBA(1, 1, 1, 0.95)
            t.authorColor = RGBA(1, 1, 1, 0.60)
            t.borderColor = RGBA(1, 1, 1, 0.18)
            return t
        }(),
        {
            var t = Theme(); t.name = "Emerald"
            t.background = .gradient
            t.gradientTop = RGBA(0.15, 0.42, 0.31); t.gradientBottom = RGBA(0.03, 0.13, 0.10)
            t.accentColor = RGBA(0.62, 0.92, 0.74)
            return t
        }(),
        {
            var t = Theme(); t.name = "Mushaf"
            t.background = .gradient
            t.gradientTop = RGBA(0.99, 0.98, 0.93); t.gradientBottom = RGBA(0.95, 0.93, 0.84)
            t.textColor = RGBA(0.10, 0.16, 0.13)
            t.authorColor = RGBA(0.10, 0.16, 0.13, 0.60)
            t.accentColor = RGBA(0.16, 0.42, 0.30)
            t.borderColor = RGBA(0.16, 0.42, 0.30, 0.25)
            t.borderWidth = 2
            return t
        }(),
        {
            var t = Theme(); t.name = "Mono"
            t.background = .solid
            t.solidColor = RGBA(0.98, 0.98, 0.98)
            t.textColor = RGBA(0.08, 0.08, 0.08)
            t.authorColor = RGBA(0.08, 0.08, 0.08, 0.55)
            t.accentColor = RGBA(0.30, 0.30, 0.30)
            t.borderColor = RGBA(0, 0, 0, 0.12)
            return t
        }(),
    ]
}
