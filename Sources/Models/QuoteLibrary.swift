import Foundation
import Combine

/// Loads the bundled quote sets and serves filtered pools to each widget.
final class QuoteLibrary: ObservableObject {
    static let shared = QuoteLibrary()

    @Published private(set) var bundled: [Quote] = []

    private init() { bundled = Self.loadBundled() }

    /// Each file carries one language; `source` comes from the JSON itself.
    private static let files: [(String, Language)] = [
        ("quotes_en", .en), ("quotes_ar", .ar),
        ("quotes_quran", .ar), ("quotes_hadith", .ar),
    ]

    private static func loadBundled() -> [Quote] {
        var all: [Quote] = []
        for (file, lang) in files {
            guard let url = Bundle.main.url(forResource: file, withExtension: "json",
                                            subdirectory: "Data")
                    ?? Bundle.main.url(forResource: file, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  var quotes = try? JSONDecoder().decode([Quote].self, from: data)
            else { continue }
            for i in quotes.indices { quotes[i].lang = lang }
            all.append(contentsOf: quotes)
        }
        return all
    }

    /// Bundled + user-authored, minus any source switched off app-wide.
    var allQuotes: [Quote] {
        let off = AppSettings.shared.disabledSources
        let all = bundled + AppSettings.shared.customQuotes
        return off.isEmpty ? all : all.filter { !off.contains($0.source) }
    }

    /// Ignores the app-wide source switches — used by the settings UI so a
    /// disabled source still shows its real total.
    var everyQuote: [Quote] { bundled + AppSettings.shared.customQuotes }

    /// Categories that actually occur, for the given language mode.
    func categories(for mode: LanguageMode) -> [QuoteCategory] {
        var seen = Set<QuoteCategory>()
        for q in allQuotes where mode.includes(q.lang) { seen.formUnion(q.categories) }
        return QuoteCategory.allCases.filter { seen.contains($0) }
    }

    /// Sources that actually occur, for the given language mode.
    func sources(for mode: LanguageMode) -> [QuoteSource] {
        var seen = Set<QuoteSource>()
        for q in allQuotes where mode.includes(q.lang) { seen.insert(q.source) }
        return QuoteSource.allCases.filter { seen.contains($0) }
    }

    func count(source: QuoteSource, mode: LanguageMode) -> Int {
        allQuotes.filter { mode.includes($0.lang) && $0.source == source }.count
    }

    func count(category: QuoteCategory, mode: LanguageMode) -> Int {
        allQuotes.filter { mode.includes($0.lang) && $0.categories.contains(category) }.count
    }

    /// The pool a widget draws from, after every filter is applied.
    ///
    /// Filters compose as: draw-from (all / favourites / a collection),
    /// then language, then source, then category. An empty source or category
    /// selection means "no restriction on that axis", not "match nothing".
    func pool(for cfg: WidgetConfig) -> [Quote] {
        let settings = AppSettings.shared

        var base: [Quote]
        switch cfg.drawFrom {
        case .all:
            base = allQuotes
        case .favorites:
            base = allQuotes.filter { settings.favorites.contains($0.id) }
        case .collection(let id):
            guard let c = settings.collections.first(where: { $0.id == id }) else {
                base = allQuotes; break
            }
            let ids = Set(c.quoteIDs)
            base = allQuotes.filter { ids.contains($0.id) }
        }

        let cats = Set(cfg.selectedCategories)
        let srcs = Set(cfg.selectedSources)
        let maxChars = cfg.lengthLimit.maxChars(area: cfg.frame.w * cfg.frame.h)
        let result = base.filter { q in
            guard cfg.languageMode.includes(q.lang) else { return false }
            if !srcs.isEmpty && !srcs.contains(q.source) { return false }
            if !cats.isEmpty && cats.isDisjoint(with: Set(q.categories)) { return false }
            if let maxChars, q.text.count > maxChars { return false }
            return true
        }

        // Never hand back an empty pool — an empty widget just looks broken.
        // Relax the narrowest axes first so the result stays as close to the
        // user's intent as possible. Length goes first: a quote of the right
        // topic rendered small beats the wrong topic at the right size.
        if !result.isEmpty { return result }
        let noLength = base.filter { q in
            cfg.languageMode.includes(q.lang)
                && (srcs.isEmpty || srcs.contains(q.source))
                && (cats.isEmpty || !cats.isDisjoint(with: Set(q.categories)))
        }
        if !noLength.isEmpty { return noLength }
        let noCats = base.filter { cfg.languageMode.includes($0.lang)
            && (srcs.isEmpty || srcs.contains($0.source)) }
        if !noCats.isEmpty { return noCats }
        let langOnly = allQuotes.filter { cfg.languageMode.includes($0.lang) }
        return langOnly.isEmpty ? allQuotes : langOnly
    }

    /// How many quotes survive the current filters at a given length ceiling —
    /// used by the settings UI to show the effect before the user commits.
    func count(for cfg: WidgetConfig, limit: LengthLimit) -> Int {
        var c = cfg
        c.lengthLimit = limit
        let maxChars = limit.maxChars(area: cfg.frame.w * cfg.frame.h)
        let cats = Set(cfg.selectedCategories), srcs = Set(cfg.selectedSources)
        return allQuotes.filter { q in
            cfg.languageMode.includes(q.lang)
                && (srcs.isEmpty || srcs.contains(q.source))
                && (cats.isEmpty || !cats.isDisjoint(with: Set(q.categories)))
                && (maxChars == nil || q.text.count <= maxChars!)
        }.count
    }

    /// True when the widget's filters select nothing and the pool was relaxed.
    func filtersAreEmpty(for cfg: WidgetConfig) -> Bool {
        let settings = AppSettings.shared
        let cats = Set(cfg.selectedCategories)
        let srcs = Set(cfg.selectedSources)
        var base: [Quote]
        switch cfg.drawFrom {
        case .all: base = allQuotes
        case .favorites: base = allQuotes.filter { settings.favorites.contains($0.id) }
        case .collection(let id):
            let ids = Set(settings.collections.first { $0.id == id }?.quoteIDs ?? [])
            base = allQuotes.filter { ids.contains($0.id) }
        }
        return !base.contains { q in
            cfg.languageMode.includes(q.lang)
                && (srcs.isEmpty || srcs.contains(q.source))
                && (cats.isEmpty || !cats.isDisjoint(with: Set(q.categories)))
        }
    }
}

/// Picks the next quote for one widget, remembering position so
/// "in order" advances and "random" avoids immediate repeats.
final class ShuffleEngine {
    private var lastPicked: String?
    private var cursor: Int = 0

    func reset(to index: Int) { cursor = max(0, index) }
    var currentIndex: Int { cursor }

    func next(from pool: [Quote], order: ShuffleOrder) -> Quote? {
        guard !pool.isEmpty else { return nil }
        switch order {
        case .sequential:
            let q = pool[cursor % pool.count]
            cursor = (cursor + 1) % pool.count
            lastPicked = q.id
            return q
        case .random:
            guard pool.count > 1 else { lastPicked = pool[0].id; return pool[0] }
            var q = pool.randomElement()!
            var attempts = 0
            while q.id == lastPicked && attempts < 12 {
                q = pool.randomElement()!; attempts += 1
            }
            lastPicked = q.id
            cursor = pool.firstIndex(of: q) ?? 0
            return q
        }
    }

    func current(from pool: [Quote]) -> Quote? {
        guard !pool.isEmpty else { return nil }
        return pool[cursor % pool.count]
    }
}
