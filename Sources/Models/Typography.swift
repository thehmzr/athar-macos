import AppKit

/// Typographic ratios for the widget, in one place so the measurement pass and
/// the render pass cannot drift apart.
///
/// Every value here is expressed as a multiple of the fitted quote size, so the
/// relationships hold at any widget dimension.
enum Typography {

    // MARK: - Vertical rhythm

    /// Gap between the quote and its English gloss.
    ///
    /// Deliberately tighter than `referenceGap`: the gloss is a translation *of*
    /// the quote and belongs to it, while the citation is a separate fact about
    /// it. Equal gaps would read as three unrelated siblings.
    static let glossGap: CGFloat = 0.30

    /// Gap before the attribution line.
    static let referenceGap: CGFloat = 0.62

    /// Leading inside a wrapped gloss, as a multiple of the gloss size.
    static let glossLineSpacing: CGFloat = 0.22

    // MARK: - Emphasis

    /// The gloss carries meaning, so it sits slightly *ahead* of the citation
    /// rather than behind it — the reference is the least informative line.
    static let glossOpacity: Double = 0.94

    /// Floor for the attribution so it stays legible on small widgets.
    static let minAuthorSize: CGFloat = 9

    // MARK: - Tracking

    /// Letter-spacing for a given size, in points.
    ///
    /// **Arabic is never tracked.** It is a connected script: inserting space
    /// between glyphs breaks the joins that define the letterforms, which is
    /// precisely the calligraphy these faces exist to render. The size-specific
    /// tracking rule is a Latin rule and applying it to Arabic actively damages
    /// the text, so the script check here is not an optimisation — it is the
    /// whole point.
    static func tracking(size: CGFloat, isArabic: Bool) -> CGFloat {
        guard !isArabic else { return 0 }
        if size >= 40 { return -size * 0.015 }   // display Latin reads loose as it grows
        if size <= 15 { return size * 0.010 }    // caption Latin needs air
        return 0
    }

    /// Leading tightens slightly as type grows, but only mildly for Arabic —
    /// the diacritics need their headroom no matter how large the verse is.
    static func lineHeightTarget(base: CGFloat, size: CGFloat, isArabic: Bool) -> CGFloat {
        guard size > 28 else { return base }
        let taper = min(isArabic ? 0.06 : 0.14, (size - 28) / 600)
        return base - taper
    }
}

/// The system accessibility switches this widget honours, republished when the
/// user changes them so open panels update live.
final class SystemPreferences: ObservableObject {
    static let shared = SystemPreferences()

    @Published private(set) var reduceTransparency: Bool
    @Published private(set) var reduceMotion: Bool
    /// Whether the system is currently in Dark Mode.
    @Published private(set) var darkAppearance: Bool

    private var appearanceObserver: NSKeyValueObservation?

    private init() {
        let ws = NSWorkspace.shared
        reduceTransparency = ws.accessibilityDisplayShouldReduceTransparency
        reduceMotion = ws.accessibilityDisplayShouldReduceMotion
        darkAppearance = Self.isDark(NSApp?.effectiveAppearance)

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in
                let ws = NSWorkspace.shared
                self?.reduceTransparency = ws.accessibilityDisplayShouldReduceTransparency
                self?.reduceMotion = ws.accessibilityDisplayShouldReduceMotion
            }

        // Light/Dark switches arrive as a change to the app's effective
        // appearance rather than as a workspace notification.
        appearanceObserver = NSApp?.observe(\.effectiveAppearance) { [weak self] app, _ in
            DispatchQueue.main.async {
                self?.darkAppearance = Self.isDark(app.effectiveAppearance)
            }
        }
    }

    private static func isDark(_ a: NSAppearance?) -> Bool {
        a?.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
