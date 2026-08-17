import SwiftUI
import AppKit

/// Measures text and solves for the largest font size that fits a box.
enum TextFitter {

    static func measure(_ text: String, font: NSFont, lineSpacing: CGFloat,
                        alignment: NSTextAlignment, rtl: Bool, width: CGFloat,
                        tracking: CGFloat = 0) -> CGSize {
        let para = NSMutableParagraphStyle()
        para.alignment = alignment
        para.lineSpacing = lineSpacing
        para.lineBreakMode = .byWordWrapping
        para.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: para]
        // Must mirror the render pass or the fit is measured against a
        // different string width than the one drawn.
        if tracking != 0 { attrs[.kern] = tracking }
        let attr = NSAttributedString(string: text, attributes: attrs)
        let rect = attr.boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading])
        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }

    /// Binary-searches the largest quote size where the quote block, the gap and
    /// the author line all fit inside `box`.
    static func fit(quote: String, author: String?, translation: String?,
                    family: String, latinFamily: String, box: CGSize,
                    lineHeightTarget: CGFloat, opticalScale: CGFloat,
                    userLineSpacing: CGFloat, authorScale: CGFloat,
                    translationScale: CGFloat, translationMinSize: CGFloat,
                    alignment: NSTextAlignment, rtl: Bool, bold: Bool,
                    minSize: CGFloat, maxSize: CGFloat) -> CGFloat {
        guard box.width > 8, box.height > 8 else { return minSize }

        func fits(_ size: CGFloat) -> Bool {
            let weight: NSFont.Weight = bold ? .bold : .regular
            let target = Typography.lineHeightTarget(base: lineHeightTarget,
                                                     size: size, isArabic: rtl)
            let f = FontCatalog.font(family: family, size: size, weight: weight)
            let spacing = FontCatalog.extraLineSpacing(font: f, target: target,
                                                       userScale: userLineSpacing)
            var h = measure(quote, font: f, lineSpacing: spacing,
                            alignment: alignment, rtl: rtl, width: box.width,
                            tracking: Typography.tracking(size: size, isArabic: rtl)).height
            // The translation is Latin text and always reads left-to-right,
            // even under a right-to-left verse.
            if let translation, !translation.isEmpty,
               size * translationScale >= translationMinSize {
                let tSize = size * translationScale
                let tf = FontCatalog.font(family: latinFamily, size: tSize, weight: .regular)
                h += size * Typography.glossGap
                h += measure(translation, font: tf,
                             lineSpacing: tSize * Typography.glossLineSpacing,
                             alignment: alignment, rtl: false, width: box.width,
                             tracking: Typography.tracking(size: tSize, isArabic: false)).height
            }
            if let author, !author.isEmpty {
                let aSize = max(Typography.minAuthorSize, size * authorScale)
                let af = FontCatalog.font(family: family, size: aSize, weight: .regular)
                h += size * Typography.referenceGap
                h += measure(author, font: af, lineSpacing: 0,
                             alignment: alignment, rtl: rtl, width: box.width,
                             tracking: Typography.tracking(size: aSize, isArabic: rtl)).height
            }
            return h <= box.height
        }

        var lo = minSize
        var hi = max(minSize, min(maxSize, box.height))
        if fits(hi) { return hi }
        // 14 iterations lands within ~0.05pt over any realistic range.
        for _ in 0..<14 {
            let mid = (lo + hi) / 2
            if fits(mid) { lo = mid } else { hi = mid }
        }
        // Deliberately *not* scaled by opticalScale: the search already
        // maximises the size that fits, so scaling the winner up would
        // overflow the box by exactly that factor.
        return max(minSize, lo)
    }
}

/// Resolves a security-scoped bookmark to an image, caching the result.
final class BackgroundImageStore {
    static let shared = BackgroundImageStore()
    private var cache: [Data: NSImage] = [:]

    func image(for bookmark: Data?) -> NSImage? {
        guard let bookmark else { return nil }
        if let img = cache[bookmark] { return img }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark,
                                 options: [.withSecurityScope],
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let img = NSImage(contentsOf: url) else { return nil }
        cache[bookmark] = img
        return img
    }
}

struct QuoteWidgetView: View {
    let widgetID: UUID
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var runtime: WidgetRuntime
    @ObservedObject var system = SystemPreferences.shared

    @State private var hovering = false
    @State private var copied = false

    private var cfg: WidgetConfig {
        settings.widget(widgetID) ?? WidgetConfig()
    }

    private var quote: Quote? { runtime.quote }

    private var isRTL: Bool { quote?.lang.isRTL ?? false }

    private var family: String {
        isRTL ? cfg.arabicFont : cfg.latinFont
    }

    private var choice: FontChoice? { FontCatalog.byFamily(family) }

    /// Colours for the current system appearance. Only adaptive (glass) themes
    /// actually change here; everything else returns its configured palette.
    private var palette: (text: RGBA, author: RGBA, translation: RGBA?, border: RGBA) {
        cfg.theme.palette(darkAppearance: system.darkAppearance)
    }

    var body: some View {
        GeometryReader { geo in
            let theme = cfg.theme
            let pad = CGFloat(theme.padding)
            let box = CGSize(width: max(10, geo.size.width - pad * 2),
                             height: max(10, geo.size.height - pad * 2))

            ZStack {
                background(theme)

                content(box: box, theme: theme)
                    .padding(pad)
                    .frame(width: geo.size.width, height: geo.size.height,
                           alignment: cfg.alignment.frameAlignment)

                if hovering && !cfg.clickThrough {
                    toolbar(theme)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .strokeBorder(borderGradient(theme),
                                  lineWidth: theme.borderEnabled ? theme.borderWidth : 0)
            )
            .shadow(color: .black.opacity(theme.shadowEnabled ? theme.shadowOpacity : 0),
                    radius: shadowRadius(theme, size: geo.size),
                    x: 0, y: shadowRadius(theme, size: geo.size) * 0.25)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
        }
        .ignoresSafeArea()
    }

    // MARK: - Depth

    /// Shadow depth encodes how far off the desktop the panel actually sits.
    ///
    /// A desktop-pinned widget rests *on* the desktop; a deep drop shadow would
    /// claim it floats above the windows it is in fact behind. Larger surfaces
    /// also read as thicker, so area contributes a little.
    private func shadowRadius(_ theme: Theme, size: CGSize) -> Double {
        let elevation: Double
        switch cfg.level {
        case .desktop:  elevation = 0.40
        case .normal:   elevation = 0.85
        case .floating: elevation = 1.25
        }
        let area = Double(min(size.width * size.height, 500_000))
        let bulk = 0.85 + 0.30 * (area / 500_000)
        return theme.shadowRadius * elevation * bulk
    }

    /// A material catches light from above; a uniform hairline reads as a drawn
    /// rectangle rather than an edge.
    private func borderGradient(_ theme: Theme) -> LinearGradient {
        let c = palette.border
        let top = Color(.sRGB, red: min(1, c.r + 0.35), green: min(1, c.g + 0.35),
                        blue: min(1, c.b + 0.35), opacity: min(1, c.a * 1.5))
        let bottom = c.withAlpha(c.a * 0.55).color
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Background

    @ViewBuilder
    private func background(_ theme: Theme) -> some View {
        Group {
            switch theme.background {
            case .solid:
                theme.solidColor.color
            case .gradient:
                LinearGradient(colors: [theme.gradientTop.color, theme.gradientBottom.color],
                               startPoint: theme.gradientStartPoint,
                               endPoint: theme.gradientEndPoint)
            case .glass:
                // Reduce Transparency asks for a frosty, near-solid surface
                // rather than a live blur of whatever is behind.
                if system.reduceTransparency {
                    theme.solidColor.color
                } else {
                    VisualEffectBackground(material: theme.glassMaterial.nsMaterial,
                                           cornerRadius: theme.cornerRadius)
                }
            case .image:
                ZStack {
                    theme.solidColor.color
                    if let img = BackgroundImageStore.shared.image(for: theme.imageBookmark) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: theme.imageBlur)
                            .opacity(theme.imageOpacity)
                    }
                }
            }
        }
        .opacity(theme.backgroundOpacity)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(box: CGSize, theme: Theme) -> some View {
        if let q = quote {
            let authorText = cfg.showAuthor && !q.author.isEmpty ? q.author : nil
            let translationText = translationToShow(q)
            let target = choice?.lineHeightTarget ?? 1.40
            let size = cfg.autoFit
                ? TextFitter.fit(quote: displayText(q),
                                 author: authorText.map(attribution),
                                 translation: translationText,
                                 family: family, latinFamily: cfg.latinFont, box: box,
                                 lineHeightTarget: target,
                                 opticalScale: choice?.opticalScale ?? 1.0,
                                 userLineSpacing: cfg.lineSpacing,
                                 authorScale: cfg.authorScale,
                                 translationScale: cfg.translationScale,
                                 translationMinSize: cfg.translationMinSize,
                                 alignment: nsAlignment, rtl: isRTL, bold: cfg.boldText,
                                 minSize: cfg.minFontSize,
                                 maxSize: cfg.maxFontSize) * cfg.textScale
                : cfg.fixedFontSize * (choice?.opticalScale ?? 1.0)

            let nsFont = FontCatalog.font(family: family, size: size,
                                          weight: cfg.boldText ? .bold : .regular)
            let spacing = FontCatalog.extraLineSpacing(font: nsFont, target: target,
                                                       userScale: cfg.lineSpacing)
            // Drop the translation rather than let it shrink the verse when the
            // widget is too small to render it legibly.
            let translationSize = size * cfg.translationScale
            let showTranslation = translationText != nil
                && translationSize >= cfg.translationMinSize

            // Spacing is applied per-gap rather than uniformly on the VStack so
            // it matches what the fitter reserved, and so the gloss groups with
            // the quote instead of floating between it and the citation.
            VStack(alignment: stackAlignment, spacing: 0) {
                Text(displayText(q))
                    .font(Font(nsFont))
                    .tracking(Typography.tracking(size: size, isArabic: isRTL))
                    .lineSpacing(spacing)
                    .foregroundStyle(palette.text.color)
                    .multilineTextAlignment(cfg.alignment.swiftUI)
                    .fixedSize(horizontal: false, vertical: true)
                    // Insurance: boundingRect and SwiftUI's layout agree closely
                    // but not exactly, and a clipped verse is unacceptable.
                    .minimumScaleFactor(0.92)

                if showTranslation, let translationText {
                    Text(translationText)
                        .font(Font(FontCatalog.font(family: cfg.latinFont,
                                                    size: translationSize)))
                        .tracking(Typography.tracking(size: translationSize, isArabic: false))
                        .lineSpacing(translationSize * Typography.glossLineSpacing)
                        .foregroundStyle(glossColor(theme))
                        // The gloss reads left-to-right even under an RTL verse,
                        // but must flush to the same visual edge as it — so the
                        // alignment is mirrored, not inherited. Without this the
                        // wrapped gloss rags the opposite way and reads as a
                        // separate column.
                        .multilineTextAlignment(glossAlignment)
                        .fixedSize(horizontal: false, vertical: true)
                        .environment(\.layoutDirection, .leftToRight)
                        .padding(.top, size * Typography.glossGap)
                }

                if let authorText {
                    let aSize = max(Typography.minAuthorSize, size * cfg.authorScale)
                    Text(attribution(authorText))
                        .font(Font(FontCatalog.font(family: family, size: aSize)))
                        .tracking(Typography.tracking(size: aSize, isArabic: isRTL))
                        .foregroundStyle(palette.author.color)
                        .multilineTextAlignment(cfg.alignment.swiftUI)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, size * Typography.referenceGap)
                }
            }
            .frame(maxWidth: .infinity, alignment: cfg.alignment.frameAlignment)
            .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
            .id(q.id)
            .transition(quoteTransition)
        } else {
            // Scales with the widget like everything else — a hardcoded size
            // would vanish on a banner and overflow a small tile.
            let s = min(max(box.height * 0.09, 11), 26)
            Text("No quotes match these filters")
                .font(Font(FontCatalog.font(family: cfg.latinFont, size: s)))
                .tracking(Typography.tracking(size: s, isArabic: false))
                .foregroundStyle(palette.author.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The attribution line, with its leading dash.
    ///
    /// An em dash at the start of an Arabic string is a bidi *neutral*, so which
    /// side it lands on depends on the resolved paragraph direction — it ends up
    /// on the left whenever that resolves to LTR, which reads as though the dash
    /// trails the name. A RIGHT-TO-LEFT MARK before it pins it to the right under
    /// either resolution, so the dash always precedes the name in reading order.
    private func attribution(_ author: String) -> String {
        isRTL ? "\u{200F}\u{2014} \(author)" : "\u{2014} \(author)"
    }

    /// An explicit gloss colour wins; otherwise it derives from the attribution
    /// colour so untouched themes look exactly as they did.
    private func glossColor(_ theme: Theme) -> Color {
        let p = palette
        if let c = p.translation { return c.color }
        return p.author.color.opacity(Typography.glossOpacity)
    }

    /// Reduce Motion keeps the cross-fade, which explains that the content
    /// changed, and drops the scale, which is the part that moves.
    private var quoteTransition: AnyTransition {
        guard cfg.animateTransitions else { return .identity }
        if system.reduceMotion { return .opacity }
        return .opacity.combined(with: .scale(scale: 0.985))
    }

    /// The gloss to show beneath a quote, or nil when there is nothing useful
    /// to add — no translation stored, the toggle is off, or the quote is
    /// already in the language the translation would be written in.
    private func translationToShow(_ q: Quote) -> String? {
        guard cfg.showTranslation, q.hasTranslation, q.lang != .en else { return nil }
        return q.translation
    }

    private func displayText(_ q: Quote) -> String {
        guard cfg.showQuoteMarks else { return q.text }
        // Qur'anic text is conventionally set in ornate brackets (U+FD3F/U+FD3E)
        // rather than ordinary quotation marks. Amiri and the other Naskh faces
        // here carry both glyphs.
        if q.source == .quran { return "\u{FD3F}\(q.text)\u{FD3E}" }
        return isRTL ? "\u{00AB}\(q.text)\u{00BB}" : "\u{201C}\(q.text)\u{201D}"
    }

    private var nsAlignment: NSTextAlignment {
        switch cfg.alignment {
        case .leading:  return isRTL ? .right : .left
        case .center:   return .center
        case .trailing: return isRTL ? .left : .right
        }
    }

    private var stackAlignment: HorizontalAlignment {
        switch cfg.alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    /// `.leading` resolves to the right edge under RTL and the left edge under
    /// LTR. The gloss is forced to LTR so its punctuation sits correctly, which
    /// means the raw alignment would send it to the opposite edge from the
    /// verse. Mirror it so both flush to the same side.
    private var glossAlignment: TextAlignment {
        guard isRTL else { return cfg.alignment.swiftUI }
        switch cfg.alignment {
        case .leading:  return .trailing
        case .center:   return .center
        case .trailing: return .leading
        }
    }

    // MARK: - Hover toolbar

    /// Stacking a light translucent chip on a translucent panel collapses
    /// legibility, so over glass the toolbar becomes an opaque surface instead.
    @ViewBuilder
    private func toolbarSurface(_ theme: Theme) -> some View {
        if theme.background == .glass && !system.reduceTransparency {
            Capsule().fill(theme.solidColor.color.opacity(0.92))
        } else if system.reduceTransparency {
            Capsule().fill(theme.solidColor.color)
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func toolbar(_ theme: Theme) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                iconButton("shuffle", help: "New quote") { runtime.shuffle() }
                iconButton(quote.map { settings.isFavorite($0) } == true
                           ? "heart.fill" : "heart", help: "Favourite") {
                    if let q = quote { settings.toggleFavorite(q) }
                }
                if !settings.collections.isEmpty, let q = quote {
                    Menu {
                        ForEach(settings.collections) { c in
                            Button {
                                settings.toggle(q, inCollection: c.id)
                            } label: {
                                Label(c.name, systemImage: settings.isIn(q, collection: c.id)
                                      ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(palette.text.color.opacity(0.85))
                    .help("Add to collection")
                }
                iconButton(copied ? "checkmark" : "doc.on.doc", help: "Copy") {
                    if let q = quote {
                        let s = q.author.isEmpty ? q.text : "\(q.text)\n— \(q.author)"
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(s, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                    }
                }
                iconButton("gearshape", help: "Settings") {
                    SettingsWindowController.shared.show(selecting: widgetID)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(toolbarSurface(theme))
            .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
            .padding(.bottom, 10)
        }
        // The toolbar floats over the attribution on short widgets. A soft
        // gradient where content meets floating chrome separates them without
        // a hard divider or a reflow.
        .background(alignment: .bottom) {
            LinearGradient(
                colors: [theme.solidColor.color.opacity(0), theme.solidColor.color.opacity(0.55)],
                startPoint: .top, endPoint: .bottom)
                .frame(height: 74)
                .allowsHitTesting(false)
        }
        .transition(.opacity)
    }

    private func iconButton(_ name: String, help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.text.color.opacity(0.85))
        .help(help)
    }
}
