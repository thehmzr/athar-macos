import SwiftUI
import AppKit
import ServiceManagement

@main
enum AtharMain {
    static func main() {
        if CommandLine.arguments.contains("--diagnose") {
            Diagnostics.run()
            exit(0)
        }
        if CommandLine.arguments.contains("--test-filters") {
            exit(Diagnostics.testFilters() ? 0 : 1)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu-bar app: no Dock icon, no main menu bar of its own.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// `Athar --diagnose` — verifies the bundle actually resolves its fonts and
/// quote data, which is easy to get wrong when assembling a bundle by hand.
enum Diagnostics {
    static func run() {
        FontCatalog.registerBundledFonts()
        let lib = QuoteLibrary.shared
        let en = lib.bundled.filter { $0.lang == .en }.count
        let ar = lib.bundled.filter { $0.lang == .ar }.count
        print("bundle:  \(Bundle.main.bundlePath)")
        print("quotes:  \(lib.bundled.count) total — \(en) English, \(ar) Arabic")

        var missing: [String] = []
        for f in FontCatalog.arabic {
            let resolved = FontCatalog.font(family: f.family, size: 20)
            // A failed lookup silently falls back to the system font.
            if resolved.familyName != f.family { missing.append(f.family) }
        }
        print("fonts:   \(FontCatalog.arabic.count - missing.count)/\(FontCatalog.arabic.count) Arabic faces resolved")
        if !missing.isEmpty { print("MISSING: \(missing.joined(separator: ", "))") }

        // Latin faces silently fall back to the system font when a family name
        // does not resolve, which is exactly how the New York default broke.
        var latinBad: [String] = []
        for f in FontCatalog.latin {
            let r = FontCatalog.font(family: f.family, size: 20)
            if let design = FontCatalog.systemDesign(for: f.family) {
                let plain = NSFont.systemFont(ofSize: 20)
                if design != .default && r.fontName == plain.fontName { latinBad.append(f.label) }
            } else if r.familyName != f.family {
                latinBad.append(f.label)
            }
        }
        print("latin:   \(FontCatalog.latin.count - latinBad.count)/\(FontCatalog.latin.count) Latin faces resolved")
        print("inuse:   \(AppSettings.shared.debugFontSummary)")
        if !latinBad.isEmpty { print("BAD:     \(latinBad.joined(separator: ", "))") }
        missing.append(contentsOf: latinBad)

        for s in QuoteSource.allCases {
            let n = lib.count(source: s, mode: .both)
            print(String(format: "  %-11@ %4d", s.en as NSString, n))
        }
        let scripture = lib.bundled.filter { $0.source == .quran || $0.source == .hadith }
        let translated = scripture.filter(\.hasTranslation).count
        print("transl:  \(translated)/\(scripture.count) scripture quotes have an English meaning")
        if translated != scripture.count {
            for q in scripture where !q.hasTranslation { print("  NO TRANS: \(q.text.prefix(40))") }
        }

        let cats = lib.categories(for: .both)
        print("cats:    \(cats.count) categories — \(cats.map(\.en).joined(separator: ", "))")

        var cfg = WidgetConfig()
        cfg.languageMode = .both
        print("pool:    \(lib.pool(for: cfg).count) quotes with default filters")

        // Every source and category must yield a non-empty pool on its own,
        // or a user selecting it would silently fall back to a wider set.
        var empties: [String] = []
        for s in QuoteSource.allCases {
            var c = WidgetConfig(); c.selectedSources = [s]
            if lib.filtersAreEmpty(for: c) { empties.append(s.en) }
        }
        for k in QuoteCategory.allCases {
            var c = WidgetConfig(); c.selectedCategories = [k]
            if lib.filtersAreEmpty(for: c) { empties.append(k.en) }
        }
        if !empties.isEmpty { print("EMPTY:   \(empties.joined(separator: ", "))") }

        print(missing.isEmpty && lib.bundled.count > 0 && empties.isEmpty
              && translated == scripture.count ? "OK" : "FAILED")
    }

    /// `Athar --test-filters` — checks that every quote a filter returns
    /// actually satisfies that filter, and that impossible combinations are
    /// reported as relaxed rather than silently returning wrong quotes.
    static func testFilters() -> Bool {
        let lib = QuoteLibrary.shared
        var failures = 0

        func check(_ label: String, expectRelaxed: Bool = false,
                   _ mutate: (inout WidgetConfig) -> Void) {
            var c = WidgetConfig()
            mutate(&c)
            let pool = lib.pool(for: c)
            let relaxed = lib.filtersAreEmpty(for: c)

            var violations = 0
            if !relaxed {
                let cats = Set(c.selectedCategories), srcs = Set(c.selectedSources)
                for q in pool {
                    if !c.languageMode.includes(q.lang) { violations += 1; continue }
                    if !srcs.isEmpty && !srcs.contains(q.source) { violations += 1; continue }
                    if !cats.isEmpty && cats.isDisjoint(with: Set(q.categories)) { violations += 1 }
                }
            }
            var note = ""
            if violations > 0 { note = "  FAIL \(violations) violations"; failures += 1 }
            else if relaxed != expectRelaxed {
                note = "  FAIL relaxed=\(relaxed) expected=\(expectRelaxed)"; failures += 1
            } else if relaxed { note = "  (relaxed, as expected)" }
            if pool.isEmpty { note += "  FAIL empty pool"; failures += 1 }
            print(String(format: "  %-42@ %4d%@", label as NSString, pool.count, note as NSString))
        }

        check("all")                           { _ in }
        check("arabic only")                   { $0.languageMode = .arabic }
        check("english only")                  { $0.languageMode = .english }
        check("quran")                         { $0.selectedSources = [.quran] }
        check("hadith")                        { $0.selectedSources = [.hadith] }
        check("quran + hadith")                { $0.selectedSources = [.quran, .hadith] }
        check("poetry, arabic")                { $0.selectedSources = [.poetry]; $0.languageMode = .arabic }
        check("category: patience")            { $0.selectedCategories = [.patience] }
        check("category: faith")               { $0.selectedCategories = [.faith] }
        check("quran + patience")              { $0.selectedSources = [.quran]; $0.selectedCategories = [.patience] }
        check("hadith + knowledge")            { $0.selectedSources = [.hadith]; $0.selectedCategories = [.knowledge] }
        check("quran + motivation")            { $0.selectedSources = [.quran]; $0.selectedCategories = [.motivation] }
        check("philosophy + en + wisdom")      { $0.selectedSources = [.philosophy]; $0.languageMode = .english; $0.selectedCategories = [.wisdom] }
        // Qur'an is Arabic-only, so this genuinely cannot match.
        check("impossible: quran + english", expectRelaxed: true) {
            $0.selectedSources = [.quran]; $0.languageMode = .english
        }

        let col = AppSettings.shared.addCollection(named: "TestCollection")
        for q in lib.allQuotes.prefix(7) { AppSettings.shared.toggle(q, inCollection: col.id) }
        check("collection (7 quotes)")         { $0.drawFrom = .collection(col.id) }
        for q in lib.allQuotes.prefix(4) { AppSettings.shared.toggleFavorite(q) }
        check("favourites (4 quotes)")         { $0.drawFrom = .favorites }
        AppSettings.shared.removeCollection(col.id)

        print(failures == 0 ? "FILTERS OK" : "FILTERS FAILED (\(failures))")
        return failures == 0
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontCatalog.registerBundledFonts()
        buildStatusItem()
        PanelController.shared.start()
        syncLoginItem()
        presentFirstRunIfNeeded()
    }

    /// A desktop-level widget sits behind every open window, so on a fresh
    /// install the user would see nothing at all. Surface it once.
    private func presentFirstRunIfNeeded() {
        let key = "AtharDidFirstRun"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let id = AppSettings.shared.widgets.first?.id {
                PanelController.shared.flash(id, duration: 3.5)
            }
            SettingsWindowController.shared.show(selecting: AppSettings.shared.widgets.first?.id)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppSettings.shared.save()
    }

    // MARK: - Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "quote.bubble",
                                   accessibilityDescription: "Athar")
            button.image?.isTemplate = true
        }
        rebuildMenu()
    }

    /// Rebuilt on open so the widget list and toggles reflect current state.
    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        populate(menu)
    }

    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(item("Shuffle All Widgets", "s", #selector(shuffleAll)))
        menu.addItem(.separator())

        let header = NSMenuItem(title: "Widgets", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for cfg in AppSettings.shared.widgets {
            let mi = NSMenuItem(title: cfg.name, action: #selector(toggleWidget(_:)),
                                keyEquivalent: "")
            mi.target = self
            mi.state = cfg.visible ? .on : .off
            mi.representedObject = cfg.id.uuidString
            mi.indentationLevel = 1
            menu.addItem(mi)
        }

        menu.addItem(.separator())
        menu.addItem(item("New Widget", "n", #selector(newWidget)))
        menu.addItem(item("Settings…", ",", #selector(openSettings)))

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin),
                               keyEquivalent: "")
        login.target = self
        login.state = AppSettings.shared.launchAtLogin ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("Quit Athar", "q", #selector(quit)))
    }

    private func item(_ title: String, _ key: String, _ sel: Selector) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        mi.target = self
        return mi
    }

    // MARK: - Actions

    @objc private func shuffleAll() { PanelController.shared.shuffleAll() }

    @objc private func newWidget() {
        let w = AppSettings.shared.addWidget()
        SettingsWindowController.shared.show(selecting: w.id)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show(selecting: AppSettings.shared.widgets.first?.id)
    }

    @objc private func toggleWidget(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String, let id = UUID(uuidString: s) else { return }
        AppSettings.shared.update(id) { $0.visible.toggle() }
    }

    @objc private func toggleLogin() {
        AppSettings.shared.launchAtLogin.toggle()
        syncLoginItem()
    }

    private func syncLoginItem() {
        let want = AppSettings.shared.launchAtLogin
        do {
            if want, SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            } else if !want, SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Unsigned/ad-hoc builds can be refused by the login-item service;
            // the preference is still remembered.
            NSLog("Athar: login item update failed — \(error.localizedDescription)")
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) { populate(menu) }
}
