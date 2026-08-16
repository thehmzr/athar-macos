import SwiftUI
import Combine

enum ShuffleOrder: String, Codable, CaseIterable {
    case random, sequential
    var displayName: String { self == .random ? "Random" : "In order" }
}

enum ShuffleInterval: String, Codable, CaseIterable {
    case manual, s10, s30, m1, m5, m15, m30, h1, h6, daily

    var displayName: String {
        switch self {
        case .manual: return "Manual only"
        case .s10:    return "Every 10 seconds"
        case .s30:    return "Every 30 seconds"
        case .m1:     return "Every minute"
        case .m5:     return "Every 5 minutes"
        case .m15:    return "Every 15 minutes"
        case .m30:    return "Every 30 minutes"
        case .h1:     return "Every hour"
        case .h6:     return "Every 6 hours"
        case .daily:  return "Once a day"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .manual: return nil
        case .s10:    return 10
        case .s30:    return 30
        case .m1:     return 60
        case .m5:     return 300
        case .m15:    return 900
        case .m30:    return 1800
        case .h1:     return 3600
        case .h6:     return 21600
        case .daily:  return 86400
        }
    }
}

enum PanelLevel: String, Codable, CaseIterable {
    case desktop, normal, floating

    var displayName: String {
        switch self {
        case .desktop:  return "Pinned to desktop"
        case .normal:   return "Normal window"
        case .floating: return "Always on top"
        }
    }

    var windowLevel: NSWindow.Level {
        switch self {
        case .desktop:
            // Sits on the desktop, behind ordinary windows but above the wallpaper.
            return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        case .normal:   return .normal
        case .floating: return .floating
        }
    }
}

enum TextAlign: String, Codable, CaseIterable {
    case leading, center, trailing

    var displayName: String {
        switch self {
        case .leading: return "Start"
        case .center: return "Center"
        case .trailing: return "End"
        }
    }

    var swiftUI: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

/// Caps how long a quote may be, so a small widget does not get handed a verse
/// that can only be rendered at 9pt.
enum LengthLimit: String, Codable, CaseIterable {
    case auto, short, medium, long, any

    var displayName: String {
        switch self {
        case .auto:   return "Fit to widget"
        case .short:  return "Short"
        case .medium: return "Medium"
        case .long:   return "Long"
        case .any:    return "Any length"
        }
    }

    /// Character ceiling, or nil for no limit.
    ///
    /// The automatic curve is calibrated so a 260×200 widget — small enough
    /// that a long verse becomes unreadable — asks for roughly 80 characters,
    /// which is about where Arabic still sets at a comfortable size there.
    func maxChars(area: Double) -> Int? {
        switch self {
        case .any:    return nil
        case .short:  return 80
        case .medium: return 150
        case .long:   return 260
        case .auto:   return Int(min(max(area / 650, 45), 400))
        }
    }

    var hint: String {
        switch self {
        case .auto:   return "Derives the limit from this widget's size — smaller widget, shorter quotes."
        case .short:  return "Up to about 80 characters."
        case .medium: return "Up to about 150 characters."
        case .long:   return "Up to about 260 characters."
        case .any:    return "No limit — long verses will render small on a small widget."
        }
    }
}

/// Which set a widget draws from before topic/source filters narrow it.
enum DrawSource: Codable, Hashable {
    case all
    case favorites
    case collection(UUID)

    var isCollection: Bool { if case .collection = self { return true }; return false }
    var collectionID: UUID? { if case .collection(let id) = self { return id }; return nil }
}

/// Everything that defines one on-screen widget panel.
struct WidgetConfig: Codable, Identifiable, Hashable {
    /// Declared explicitly because the lenient `init(from:)` below suppresses
    /// synthesis of these keys.
    enum CodingKeys: String, CodingKey {
        case id, name, theme
        case arabicFont, latinFont, textScale, minFontSize, maxFontSize
        case autoFit, fixedFontSize, boldText, lineSpacing, alignment
        case showAuthor, showQuoteMarks, authorScale
        case showTranslation, translationScale, translationMinSize
        case languageMode, selectedCategories, selectedSources, drawFrom, lengthLimit
        case shuffleInterval, shuffleOrder, animateTransitions
        case frame, level, locked, clickThrough, stickyAllSpaces, visible, windowOpacity
        case lastQuoteIndex
    }

    var id: UUID = UUID()
    var name: String = "Quote"

    var theme: Theme = Theme.presets[0]

    // Typography
    var arabicFont: String = "Amiri"
    var latinFont: String = FontCatalog.serifSentinel   // New York
    var textScale: Double = 1.0          // multiplier on the auto-fitted size
    var minFontSize: Double = 11
    var maxFontSize: Double = 120
    var autoFit: Bool = true
    var fixedFontSize: Double = 22
    var boldText: Bool = false
    var lineSpacing: Double = 1.0        // multiplier on the face's natural leading
    var alignment: TextAlign = .center
    var showAuthor: Bool = true
    /// Off by default — the quote is the whole widget, so the marks read as
    /// clutter rather than punctuation.
    var showQuoteMarks: Bool = false
    var authorScale: Double = 0.5        // relative to quote text size
    /// English meaning under Arabic scripture, sized near the reference line.
    var showTranslation: Bool = true
    var translationScale: Double = 0.42  // relative to quote text size
    /// Below this the translation is illegible, so it is dropped rather than
    /// allowed to shrink the verse it is meant to support.
    var translationMinSize: Double = 9

    // Content
    var languageMode: LanguageMode = .both
    /// Empty means "no restriction on this axis", not "match nothing".
    var selectedCategories: [QuoteCategory] = []
    var selectedSources: [QuoteSource] = []
    var drawFrom: DrawSource = .all
    /// Keeps long verses off small widgets; see `LengthLimit`.
    var lengthLimit: LengthLimit = .auto

    // Shuffle
    var shuffleInterval: ShuffleInterval = .m15
    var shuffleOrder: ShuffleOrder = .random
    var animateTransitions: Bool = true

    // Window
    var frame: CodableRect = CodableRect(x: 200, y: 200, w: 420, h: 300)
    var level: PanelLevel = .desktop
    var locked: Bool = false             // ignore drags/resizes
    var clickThrough: Bool = false       // mouse events pass to what's beneath
    var stickyAllSpaces: Bool = true
    var visible: Bool = true
    var windowOpacity: Double = 1.0

    // Runtime bookkeeping
    var lastQuoteIndex: Int = 0
}

extension KeyedDecodingContainer {
    /// Decode a field, falling back to `fallback` when it is absent *or* stored
    /// with an incompatible type.
    ///
    /// Synthesized `Codable` throws on the first missing key, which — combined
    /// with a `try?` at the call site — silently resets every stored setting the
    /// moment a new field is added. Widget layouts and themes are expensive for
    /// a user to recreate, so each field degrades on its own instead.
    func lenient<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
}

// Written as extensions so the compiler still synthesizes the no-argument
// initialiser that supplies every default.
extension WidgetConfig {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WidgetConfig()
        self.init()
        id = c.lenient(.id, d.id)
        name = c.lenient(.name, d.name)
        theme = c.lenient(.theme, d.theme)
        arabicFont = c.lenient(.arabicFont, d.arabicFont)
        latinFont = c.lenient(.latinFont, d.latinFont)
        textScale = c.lenient(.textScale, d.textScale)
        minFontSize = c.lenient(.minFontSize, d.minFontSize)
        maxFontSize = c.lenient(.maxFontSize, d.maxFontSize)
        autoFit = c.lenient(.autoFit, d.autoFit)
        fixedFontSize = c.lenient(.fixedFontSize, d.fixedFontSize)
        boldText = c.lenient(.boldText, d.boldText)
        lineSpacing = c.lenient(.lineSpacing, d.lineSpacing)
        alignment = c.lenient(.alignment, d.alignment)
        showAuthor = c.lenient(.showAuthor, d.showAuthor)
        showQuoteMarks = c.lenient(.showQuoteMarks, d.showQuoteMarks)
        authorScale = c.lenient(.authorScale, d.authorScale)
        showTranslation = c.lenient(.showTranslation, d.showTranslation)
        translationScale = c.lenient(.translationScale, d.translationScale)
        translationMinSize = c.lenient(.translationMinSize, d.translationMinSize)
        languageMode = c.lenient(.languageMode, d.languageMode)
        selectedCategories = c.lenient(.selectedCategories, d.selectedCategories)
        selectedSources = c.lenient(.selectedSources, d.selectedSources)
        drawFrom = c.lenient(.drawFrom, d.drawFrom)
        lengthLimit = c.lenient(.lengthLimit, d.lengthLimit)
        shuffleInterval = c.lenient(.shuffleInterval, d.shuffleInterval)
        shuffleOrder = c.lenient(.shuffleOrder, d.shuffleOrder)
        animateTransitions = c.lenient(.animateTransitions, d.animateTransitions)
        frame = c.lenient(.frame, d.frame)
        level = c.lenient(.level, d.level)
        locked = c.lenient(.locked, d.locked)
        clickThrough = c.lenient(.clickThrough, d.clickThrough)
        stickyAllSpaces = c.lenient(.stickyAllSpaces, d.stickyAllSpaces)
        visible = c.lenient(.visible, d.visible)
        windowOpacity = c.lenient(.windowOpacity, d.windowOpacity)
        lastQuoteIndex = c.lenient(.lastQuoteIndex, d.lastQuoteIndex)
    }
}

extension Theme {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Theme()
        self.init()
        name = c.lenient(.name, d.name)
        background = c.lenient(.background, d.background)
        solidColor = c.lenient(.solidColor, d.solidColor)
        gradientTop = c.lenient(.gradientTop, d.gradientTop)
        gradientBottom = c.lenient(.gradientBottom, d.gradientBottom)
        gradientAngle = c.lenient(.gradientAngle, d.gradientAngle)
        glassMaterial = c.lenient(.glassMaterial, d.glassMaterial)
        imageBookmark = c.lenient(.imageBookmark, d.imageBookmark)
        imageOpacity = c.lenient(.imageOpacity, d.imageOpacity)
        imageBlur = c.lenient(.imageBlur, d.imageBlur)
        textColor = c.lenient(.textColor, d.textColor)
        authorColor = c.lenient(.authorColor, d.authorColor)
        accentColor = c.lenient(.accentColor, d.accentColor)
        translationColor = c.lenient(.translationColor, d.translationColor)
        glassFollowsSystem = c.lenient(.glassFollowsSystem, d.glassFollowsSystem)
        lightTextColor = c.lenient(.lightTextColor, d.lightTextColor)
        lightAuthorColor = c.lenient(.lightAuthorColor, d.lightAuthorColor)
        lightTranslationColor = c.lenient(.lightTranslationColor, d.lightTranslationColor)
        lightBorderColor = c.lenient(.lightBorderColor, d.lightBorderColor)
        cornerRadius = c.lenient(.cornerRadius, d.cornerRadius)
        padding = c.lenient(.padding, d.padding)
        backgroundOpacity = c.lenient(.backgroundOpacity, d.backgroundOpacity)
        shadowEnabled = c.lenient(.shadowEnabled, d.shadowEnabled)
        shadowRadius = c.lenient(.shadowRadius, d.shadowRadius)
        shadowOpacity = c.lenient(.shadowOpacity, d.shadowOpacity)
        borderEnabled = c.lenient(.borderEnabled, d.borderEnabled)
        borderColor = c.lenient(.borderColor, d.borderColor)
        borderWidth = c.lenient(.borderWidth, d.borderWidth)
    }
}

struct CodableRect: Codable, Hashable {
    var x: Double, y: Double, w: Double, h: Double

    init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }
    init(_ r: NSRect) {
        x = r.origin.x; y = r.origin.y; w = r.size.width; h = r.size.height
    }
    var nsRect: NSRect { NSRect(x: x, y: y, width: w, height: h) }
}

/// App-wide state, persisted as JSON in Application Support.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var widgets: [WidgetConfig] = []
    @Published var favorites: Set<String> = []
    @Published var customQuotes: [Quote] = []
    @Published var collections: [QuoteCollection] = []
    /// Sources switched off for the whole app, not just one widget. Empty by
    /// default — everything ships enabled.
    @Published var disabledSources: Set<QuoteSource> = []
    @Published var launchAtLogin: Bool = false

    private var saveTask: DispatchWorkItem?
    private var loading = false

    static var supportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Athar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private static var fileURL: URL { supportDir.appendingPathComponent("settings.json") }

    private struct Payload: Codable {
        var widgets: [WidgetConfig]
        var favorites: [String]
        var customQuotes: [Quote]
        var collections: [QuoteCollection]?
        var disabledSources: [QuoteSource]?
        var launchAtLogin: Bool
    }

    private init() {
        let migrated = load()
        // Coalesce writes — the settings UI mutates on every slider tick.
        $widgets.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(in: &bag)
        $favorites.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(in: &bag)
        $customQuotes.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(in: &bag)
        $collections.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(in: &bag)
        $disabledSources.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(in: &bag)
        $launchAtLogin.dropFirst().sink { [weak self] _ in self?.scheduleSave() }.store(in: &bag)
        // Persist the font migration so the stored file matches what is in use.
        if migrated { save() }
    }
    private var bag = Set<AnyCancellable>()

    @discardableResult
    private func load() -> Bool {
        loading = true
        defer { loading = false }
        guard let data = try? Data(contentsOf: Self.fileURL),
              let p = try? JSONDecoder().decode(Payload.self, from: data) else {
            widgets = [WidgetConfig()]
            return false
        }
        widgets = p.widgets.isEmpty ? [WidgetConfig()] : p.widgets
        favorites = Set(p.favorites)
        customQuotes = p.customQuotes
        collections = p.collections ?? []
        disabledSources = Set(p.disabledSources ?? [])
        launchAtLogin = p.launchAtLogin
        return migrateLegacyFonts()
    }

    /// Earlier builds stored "New York" and "SF Pro" as family names. Neither is
    /// addressable that way, so those settings silently rendered as the plain
    /// system font. Map them onto the design sentinels that actually resolve.
    @discardableResult
    private func migrateLegacyFonts() -> Bool {
        let legacy = [
            "New York": FontCatalog.serifSentinel,
            "SF Pro": FontCatalog.systemFamilySentinel,
        ]
        var changed = false
        for i in widgets.indices {
            if let s = legacy[widgets[i].latinFont] {
                widgets[i].latinFont = s; changed = true
            }
        }
        return changed
    }

    /// Reports the font actually in use, for `--diagnose`.
    var debugFontSummary: String {
        widgets.map { "\($0.name): latin=\($0.latinFont) arabic=\($0.arabicFont)" }
            .joined(separator: "; ")
    }

    private func scheduleSave() {
        guard !loading else { return }
        saveTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.save() }
        saveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
    }

    func save() {
        let p = Payload(widgets: widgets, favorites: Array(favorites),
                        customQuotes: customQuotes, collections: collections,
                        disabledSources: Array(disabledSources),
                        launchAtLogin: launchAtLogin)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(p) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: - Mutation helpers

    func widget(_ id: UUID) -> WidgetConfig? { widgets.first { $0.id == id } }

    func update(_ id: UUID, _ mutate: (inout WidgetConfig) -> Void) {
        guard let i = widgets.firstIndex(where: { $0.id == id }) else { return }
        mutate(&widgets[i])
    }

    /// Frame changes fire continuously during a drag; write them without
    /// republishing the whole array so we don't thrash the SwiftUI graph.
    func updateFrameSilently(_ id: UUID, _ rect: NSRect) {
        guard let i = widgets.firstIndex(where: { $0.id == id }) else { return }
        widgets[i].frame = CodableRect(rect)
        scheduleSave()
    }

    func addWidget() -> WidgetConfig {
        var w = WidgetConfig()
        w.name = "Quote \(widgets.count + 1)"
        // Cascade so a new panel doesn't land exactly on top of the last one.
        if let last = widgets.last {
            w.frame = CodableRect(x: last.frame.x + 40, y: last.frame.y - 40,
                                  w: last.frame.w, h: last.frame.h)
            w.theme = last.theme
            w.arabicFont = last.arabicFont
            w.latinFont = last.latinFont
        }
        widgets.append(w)
        return w
    }

    func removeWidget(_ id: UUID) {
        widgets.removeAll { $0.id == id }
        if widgets.isEmpty { widgets = [WidgetConfig()] }
    }

    func isFavorite(_ q: Quote) -> Bool { favorites.contains(q.id) }

    func toggleFavorite(_ q: Quote) {
        if favorites.contains(q.id) { favorites.remove(q.id) }
        else { favorites.insert(q.id) }
    }

    // MARK: - Collections

    @discardableResult
    func addCollection(named name: String, symbol: String = "folder") -> QuoteCollection {
        let c = QuoteCollection(name: name, symbol: symbol)
        collections.append(c)
        return c
    }

    func removeCollection(_ id: UUID) {
        collections.removeAll { $0.id == id }
        // Any widget pointing at the deleted folder falls back to the full set.
        for i in widgets.indices where widgets[i].drawFrom.collectionID == id {
            widgets[i].drawFrom = .all
        }
    }

    func collection(_ id: UUID) -> QuoteCollection? { collections.first { $0.id == id } }

    func isIn(_ q: Quote, collection id: UUID) -> Bool {
        collection(id)?.quoteIDs.contains(q.id) ?? false
    }

    func toggle(_ q: Quote, inCollection id: UUID) {
        guard let i = collections.firstIndex(where: { $0.id == id }) else { return }
        if let j = collections[i].quoteIDs.firstIndex(of: q.id) {
            collections[i].quoteIDs.remove(at: j)
        } else {
            collections[i].quoteIDs.append(q.id)
        }
    }

    /// Collections a quote currently belongs to.
    func collections(containing q: Quote) -> [QuoteCollection] {
        collections.filter { $0.quoteIDs.contains(q.id) }
    }
}
