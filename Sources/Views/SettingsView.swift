import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Binding where Value == RGBA {
    /// Bridges the Codable RGBA store to SwiftUI's ColorPicker.
    var asColor: Binding<Color> {
        Binding<Color>(
            get: { wrappedValue.color },
            set: { newValue in
                let ns = NSColor(newValue).usingColorSpace(.sRGB) ?? .white
                wrappedValue = RGBA(ns)
            })
    }
}

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var library = QuoteLibrary.shared
    @State var selection: UUID
    @State private var tab: Tab = .appearance

    enum Tab: String, CaseIterable {
        case appearance, typography, content, window, library
        var title: String {
            switch self {
            case .appearance: return "Appearance"
            case .typography: return "Typography"
            case .content:    return "Content"
            case .window:     return "Window"
            case .library:    return "Library"
            }
        }
        var icon: String {
            switch self {
            case .appearance: return "paintpalette"
            case .typography: return "textformat"
            case .content:    return "quote.bubble"
            case .window:     return "macwindow"
            case .library:    return "books.vertical"
            }
        }
    }

    private var cfgIndex: Int? { settings.widgets.firstIndex { $0.id == selection } }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 190, idealWidth: 205, maxWidth: 260)

            Group {
                if let i = cfgIndex {
                    let cfg = $settings.widgets[i]
                    VStack(spacing: 0) {
                        picker
                        Divider()
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                switch tab {
                                case .appearance: AppearanceTab(cfg: cfg)
                                case .typography: TypographyTab(cfg: cfg)
                                case .content:    ContentTab(cfg: cfg, library: library)
                                case .window:     WindowTab(cfg: cfg, id: selection)
                                case .library:    LibraryTab()
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    Text("Select a widget").foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 460)
        }
        .frame(minWidth: 700, minHeight: 540)
    }

    private var picker: some View {
        Picker("", selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { t in
                Label(t.title, systemImage: t.icon).tag(t)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(10)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section("Widgets") {
                    ForEach(settings.widgets) { w in
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(swatch(w.theme))
                                .frame(width: 22, height: 16)
                                .overlay(RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(.white.opacity(0.15)))
                            Text(w.name).lineLimit(1)
                            Spacer()
                            if !w.visible {
                                Image(systemName: "eye.slash")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .tag(w.id)
                        .contentShape(Rectangle())
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()
            HStack(spacing: 6) {
                Button { selection = settings.addWidget().id } label: {
                    Image(systemName: "plus")
                }.help("New widget")
                Button {
                    let id = selection
                    settings.removeWidget(id)
                    selection = settings.widgets.first?.id ?? UUID()
                } label: { Image(systemName: "minus") }
                    .disabled(settings.widgets.count <= 1)
                    .help("Delete widget")
                Spacer()
                Button { PanelController.shared.flash(selection) } label: {
                    Image(systemName: "viewfinder")
                }.help("Locate on screen")
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
    }

    private func swatch(_ t: Theme) -> LinearGradient {
        switch t.background {
        case .gradient:
            return LinearGradient(colors: [t.gradientTop.color, t.gradientBottom.color],
                                  startPoint: .top, endPoint: .bottom)
        case .solid, .image, .glass:
            return LinearGradient(colors: [t.solidColor.color, t.solidColor.color],
                                  startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Shared building blocks

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var suffix: String = ""

    var body: some View {
        HStack {
            Text(label).frame(width: 108, alignment: .leading)
            Slider(value: $value, in: range, step: step)
            Text(step < 1 ? String(format: "%.2f", value) : "\(Int(value))\(suffix)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

// MARK: - Appearance

struct AppearanceTab: View {
    @Binding var cfg: WidgetConfig
    @ObservedObject private var system = SystemPreferences.shared

    /// Binds an optional Light Mode colour, opening the picker on the derived
    /// value so it starts from what is actually on screen rather than black.
    private func lightBinding(_ key: WritableKeyPath<Theme, RGBA?>,
                              fallback: RGBA) -> Binding<Color> {
        Binding(
            get: { (cfg.theme[keyPath: key] ?? fallback).color },
            set: { cfg.theme[keyPath: key] = RGBA(NSColor($0).usingColorSpace(.sRGB) ?? .white) })
    }

    var body: some View {
        SectionCard(title: "Presets") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                ForEach(Theme.presets, id: \.name) { p in
                    Button {
                        // Keep the user's layout metrics; swap only the palette.
                        var t = p
                        t.cornerRadius = cfg.theme.cornerRadius
                        t.padding = cfg.theme.padding
                        cfg.theme = t
                    } label: {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(LinearGradient(
                                    colors: p.background == .gradient
                                        ? [p.gradientTop.color, p.gradientBottom.color]
                                        : [p.solidColor.color, p.solidColor.color],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 42)
                                .overlay(
                                    Text("\u{201C}A\u{201D}")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(p.textColor.color))
                                .overlay(RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(isActive(p) ? Color.accentColor
                                                              : .white.opacity(0.12),
                                                  lineWidth: isActive(p) ? 2 : 1))
                            Text(p.name).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }

        SectionCard(title: "Background") {
            Picker("Style", selection: $cfg.theme.background) {
                ForEach(BackgroundStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()

            switch cfg.theme.background {
            case .solid:
                ColorPicker("Colour", selection: $cfg.theme.solidColor.asColor)
            case .gradient:
                ColorPicker("Top", selection: $cfg.theme.gradientTop.asColor)
                ColorPicker("Bottom", selection: $cfg.theme.gradientBottom.asColor)
                LabeledSlider(label: "Angle", value: $cfg.theme.gradientAngle,
                              range: 0...360, suffix: "°")
            case .glass:
                Picker("Material", selection: $cfg.theme.glassMaterial) {
                    ForEach(GlassMaterial.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Toggle("Follow system Light / Dark", isOn: $cfg.theme.glassFollowsSystem)
                Text(cfg.theme.glassFollowsSystem
                     ? "The glass and its text switch together when macOS changes appearance."
                     : "Pinned to one appearance regardless of the system setting.")
                    .font(.caption).foregroundStyle(.secondary)
            case .image:
                HStack {
                    Button("Choose Image…") { pickImage() }
                    if cfg.theme.imageBookmark != nil {
                        Button("Remove") { cfg.theme.imageBookmark = nil }
                    }
                }
                LabeledSlider(label: "Opacity", value: $cfg.theme.imageOpacity,
                              range: 0...1, step: 0.01)
                LabeledSlider(label: "Blur", value: $cfg.theme.imageBlur, range: 0...40)
                ColorPicker("Behind image", selection: $cfg.theme.solidColor.asColor)
            }

            LabeledSlider(label: "Opacity", value: $cfg.theme.backgroundOpacity,
                          range: 0...1, step: 0.01)
        }

        SectionCard(title: cfg.theme.adaptsToAppearance ? "Colours — Dark Mode" : "Colours") {
            ColorPicker("Quote text", selection: $cfg.theme.textColor.asColor)
            ColorPicker("Attribution", selection: $cfg.theme.authorColor.asColor)
            Button("Match attribution to text at 60%") {
                cfg.theme.authorColor = cfg.theme.textColor.withAlpha(0.6)
            }.font(.caption)
        }

        if cfg.theme.adaptsToAppearance {
            SectionCard(title: "Colours — Light Mode") {
                Text("Used when macOS is in Light Mode. Left unset, these are "
                     + "derived from the Dark Mode colours by flipping brightness "
                     + "and keeping the hue.")
                    .font(.caption).foregroundStyle(.secondary)
                ColorPicker("Quote text", selection: lightBinding(
                    \.lightTextColor, fallback: cfg.theme.textColor.flippedBrightness))
                ColorPicker("Attribution", selection: lightBinding(
                    \.lightAuthorColor, fallback: cfg.theme.authorColor.flippedBrightness))
                HStack {
                    Button("Reset to derived") {
                        cfg.theme.lightTextColor = nil
                        cfg.theme.lightAuthorColor = nil
                        cfg.theme.lightTranslationColor = nil
                        cfg.theme.lightBorderColor = nil
                    }.font(.caption)
                    Spacer()
                    Text(system.darkAppearance ? "System is currently Dark"
                                               : "System is currently Light")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }

        SectionCard(title: "Shape") {
            LabeledSlider(label: "Corner radius", value: $cfg.theme.cornerRadius, range: 0...60)
            LabeledSlider(label: "Padding", value: $cfg.theme.padding, range: 4...90)
            Toggle("Border", isOn: $cfg.theme.borderEnabled)
            if cfg.theme.borderEnabled {
                ColorPicker("Border colour", selection: $cfg.theme.borderColor.asColor)
                LabeledSlider(label: "Border width", value: $cfg.theme.borderWidth,
                              range: 0.5...6, step: 0.5)
            }
            Toggle("Shadow", isOn: $cfg.theme.shadowEnabled)
            if cfg.theme.shadowEnabled {
                Text("Drawn by macOS, so it falls outside the widget and follows "
                     + "its corners. A shadow drawn inside the widget could only "
                     + "spread into the corners, which showed as grey wedges.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Compares the palette rather than the stored name, so a preset stops
    /// reading as "selected" the moment the user edits one of its colours.
    private func isActive(_ p: Theme) -> Bool {
        let t = cfg.theme
        guard t.name == p.name, t.background == p.background else { return false }
        switch p.background {
        case .solid, .image:
            return t.solidColor == p.solidColor && t.textColor == p.textColor
        case .gradient:
            return t.gradientTop == p.gradientTop && t.gradientBottom == p.gradientBottom
                && t.textColor == p.textColor
        case .glass:
            return t.glassMaterial == p.glassMaterial && t.textColor == p.textColor
        }
    }

    private func pickImage() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.image]
        p.allowsMultipleSelection = false
        guard p.runModal() == .OK, let url = p.url else { return }
        cfg.theme.imageBookmark = try? url.bookmarkData(
            options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        cfg.theme.background = .image
    }
}

// MARK: - Typography

struct TypographyTab: View {
    @Binding var cfg: WidgetConfig

    private let sampleAr = "الخَطُّ الجَميل"
    private let sampleEn = "The quick brown fox"

    var body: some View {
        SectionCard(title: "Arabic face") {
            ForEach(FontCatalog.arabicGrouped(), id: \.0) { script, fonts in
                Text(script.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(fonts) { f in
                        fontCell(f, sample: sampleAr, rtl: true,
                                 selected: cfg.arabicFont == f.family) {
                            cfg.arabicFont = f.family
                        }
                    }
                }
            }
        }

        SectionCard(title: "Latin face") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(FontCatalog.latin) { f in
                    fontCell(f, sample: sampleEn, rtl: false,
                             selected: cfg.latinFont == f.family) {
                        cfg.latinFont = f.family
                    }
                }
            }
        }

        SectionCard(title: "Size") {
            Toggle("Fit text to widget automatically", isOn: $cfg.autoFit)
            if cfg.autoFit {
                // Capped at 1.0: the fitter already returns the largest size
                // that fits, so anything above this would overflow the widget.
                LabeledSlider(label: "Fill", value: $cfg.textScale, range: 0.3...1.0, step: 0.01)
                LabeledSlider(label: "Min size", value: $cfg.minFontSize, range: 6...40)
                LabeledSlider(label: "Max size", value: $cfg.maxFontSize, range: 20...300)
            } else {
                LabeledSlider(label: "Font size", value: $cfg.fixedFontSize, range: 8...200)
            }
            LabeledSlider(label: "Line spacing", value: $cfg.lineSpacing, range: 0...2.5, step: 0.05)
            LabeledSlider(label: "Author size", value: $cfg.authorScale, range: 0.2...1.0, step: 0.01)
        }

        SectionCard(title: "Layout") {
            Picker("Alignment", selection: $cfg.alignment) {
                ForEach(TextAlign.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("Bold", isOn: $cfg.boldText)
            Toggle("Show attribution", isOn: $cfg.showAuthor)
            Toggle("Show quotation marks", isOn: $cfg.showQuoteMarks)
        }

        SectionCard(title: "Translation") {
            Toggle("Show English meaning under Arabic scripture", isOn: $cfg.showTranslation)
            if cfg.showTranslation {
                LabeledSlider(label: "Size", value: $cfg.translationScale,
                              range: 0.25...0.9, step: 0.01)

                HStack {
                    ColorPicker("Colour", selection: translationColorBinding)
                    if cfg.theme.translationColor != nil {
                        Button("Reset") { cfg.theme.translationColor = nil }
                            .font(.caption)
                    }
                }
                Text(cfg.theme.translationColor == nil
                     ? "Following the attribution colour. Pick one to override."
                     : "Using a custom colour.")
                    .font(.caption).foregroundStyle(.secondary)

                LabeledSlider(label: "Hide below", value: $cfg.translationMinSize,
                              range: 6...20, suffix: "pt")
                Text("Applies to Qur'an and Hadith, which carry a translation. "
                     + "It is dropped automatically when the widget gets too small "
                     + "for it to be legible, so it never squeezes the verse.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Falls back to the derived colour so the picker opens on what is actually
    /// on screen rather than on black.
    private var translationColorBinding: Binding<Color> {
        Binding(
            get: {
                if let c = cfg.theme.translationColor { return c.color }
                return cfg.theme.authorColor.color.opacity(Typography.glossOpacity)
            },
            set: { new in
                let ns = NSColor(new).usingColorSpace(.sRGB) ?? .white
                cfg.theme.translationColor = RGBA(ns)
            })
    }

    private func fontCell(_ f: FontChoice, sample: String, rtl: Bool,
                          selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(sample)
                    .font(Font(FontCatalog.font(family: f.family, size: 21)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
                    .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
                Text(f.label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5))
        }.buttonStyle(.plain)
    }
}

// MARK: - Content

struct ContentTab: View {
    @Binding var cfg: WidgetConfig
    @ObservedObject var library: QuoteLibrary
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        SectionCard(title: "Language") {
            Picker("", selection: $cfg.languageMode) {
                ForEach(LanguageMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            Text("Arabic quotes render right-to-left and use the Arabic face; English uses the Latin face.")
                .font(.caption).foregroundStyle(.secondary)
        }

        SectionCard(title: "Shuffle") {
            Picker("How often", selection: $cfg.shuffleInterval) {
                ForEach(ShuffleInterval.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Order", selection: $cfg.shuffleOrder) {
                ForEach(ShuffleOrder.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }.pickerStyle(.segmented)
            Toggle("Animate transitions", isOn: $cfg.animateTransitions)
            Button("Shuffle now") { PanelController.shared.runtime(cfg.id).shuffle() }
        }

        SectionCard(title: "Draw from") {
            Picker("", selection: drawFromBinding) {
                Text("All quotes").tag(DrawKind.all)
                Text("Favourites").tag(DrawKind.favorites)
                ForEach(settings.collections) { c in
                    Label(c.name, systemImage: c.symbol).tag(DrawKind.collection(c.id))
                }
            }.labelsHidden()

            if case .collection(let id) = cfg.drawFrom,
               let c = settings.collection(id) {
                Text("\(c.quoteIDs.count) quotes in \u{201C}\(c.name)\u{201D} — add more from the Library tab.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if case .favorites = cfg.drawFrom {
                Text("\(settings.favorites.count) favourited — tap the heart on a widget or in the Library.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }

        SectionCard(title: "Quote length") {
            Picker("", selection: $cfg.lengthLimit) {
                ForEach(LengthLimit.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            Text(cfg.lengthLimit.hint).font(.caption).foregroundStyle(.secondary)
            if let n = cfg.lengthLimit.maxChars(area: cfg.frame.w * cfg.frame.h) {
                Text("This widget is \(Int(cfg.frame.w))×\(Int(cfg.frame.h)) — "
                     + "allowing up to \(n) characters, "
                     + "\(library.count(for: cfg, limit: cfg.lengthLimit)) quotes match.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }

        SectionCard(title: "Source") {
            let sources = library.sources(for: cfg.languageMode)
            HStack {
                Text(cfg.selectedSources.isEmpty
                     ? "All sources" : "\(cfg.selectedSources.count) of \(sources.count) selected")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("All") { cfg.selectedSources = [] }.font(.caption)
                    .disabled(cfg.selectedSources.isEmpty)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 6)], spacing: 6) {
                ForEach(sources, id: \.self) { s in
                    chip(label: s.en, arabic: s.ar, symbol: s.symbol,
                         count: library.count(source: s, mode: cfg.languageMode),
                         on: cfg.selectedSources.contains(s)) {
                        toggle(s, in: &cfg.selectedSources)
                    }
                }
            }
        }

        SectionCard(title: "Category") {
            let cats = library.categories(for: cfg.languageMode)
            HStack {
                Text(cfg.selectedCategories.isEmpty
                     ? "All categories" : "\(cfg.selectedCategories.count) of \(cats.count) selected")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("All") { cfg.selectedCategories = [] }.font(.caption)
                    .disabled(cfg.selectedCategories.isEmpty)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 6)], spacing: 6) {
                ForEach(cats, id: \.self) { c in
                    chip(label: c.en, arabic: c.ar, symbol: c.symbol,
                         count: library.count(category: c, mode: cfg.languageMode),
                         on: cfg.selectedCategories.contains(c)) {
                        toggle(c, in: &cfg.selectedCategories)
                    }
                }
            }

            Divider().padding(.vertical, 2)
            let pool = library.pool(for: cfg)
            if library.filtersAreEmpty(for: cfg) {
                Label("Nothing matches these filters — showing a wider set instead.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            } else {
                Text("Pool: \(pool.count) quotes").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// `DrawSource` carries a UUID payload, so the Picker needs a plain
    /// Hashable tag type it can compare.
    private enum DrawKind: Hashable {
        case all, favorites, collection(UUID)
    }

    private var drawFromBinding: Binding<DrawKind> {
        Binding(
            get: {
                switch cfg.drawFrom {
                case .all: return .all
                case .favorites: return .favorites
                case .collection(let id): return .collection(id)
                }
            },
            set: { k in
                switch k {
                case .all: cfg.drawFrom = .all
                case .favorites: cfg.drawFrom = .favorites
                case .collection(let id): cfg.drawFrom = .collection(id)
                }
            })
    }

    private func toggle<T: Equatable>(_ v: T, in list: inout [T]) {
        if let i = list.firstIndex(of: v) { list.remove(at: i) } else { list.append(v) }
    }

    private func chip(label: String, arabic: String, symbol: String, count: Int,
                      on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 9))
                VStack(alignment: .leading, spacing: 0) {
                    Text(label).font(.system(size: 11)).lineLimit(1)
                    Text(arabic).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 2)
                Text("\(count)").font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(on ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .strokeBorder(on ? Color.accentColor : .clear, lineWidth: 1.2))
        }.buttonStyle(.plain)
    }
}

// MARK: - Window

struct WindowTab: View {
    @Binding var cfg: WidgetConfig
    let id: UUID

    var body: some View {
        SectionCard(title: "Placement") {
            Picker("Layer", selection: $cfg.level) {
                ForEach(PanelLevel.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Text(layerHint).font(.caption).foregroundStyle(.secondary)
            Toggle("Show on every Space", isOn: $cfg.stickyAllSpaces)
            Toggle("Visible", isOn: $cfg.visible)
        }

        SectionCard(title: "Interaction") {
            Toggle("Lock position and size", isOn: $cfg.locked)
            Toggle("Click through to what's behind", isOn: $cfg.clickThrough)
            if cfg.clickThrough {
                Text("With click-through on, the hover controls are unavailable — use the menu bar or this window.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LabeledSlider(label: "Window opacity", value: $cfg.windowOpacity,
                          range: 0.15...1, step: 0.01)
        }

        SectionCard(title: "Size and position") {
            HStack {
                numField("X", $cfg.frame.x)
                numField("Y", $cfg.frame.y)
            }
            HStack {
                numField("Width", $cfg.frame.w)
                numField("Height", $cfg.frame.h)
            }
            Text("Drag any edge or corner of the widget to resize it, or the top strip to move it.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                ForEach(presets, id: \.0) { name, w, h in
                    Button(name) { cfg.frame.w = w; cfg.frame.h = h; push() }
                        .font(.caption)
                }
            }
            Button("Apply") { push() }
        }

        SectionCard(title: "Name") {
            TextField("Widget name", text: $cfg.name)
        }
    }

    private var presets: [(String, Double, Double)] {
        [("Small", 260, 200), ("Medium", 420, 300), ("Large", 620, 420), ("Banner", 820, 220)]
    }

    private var layerHint: String {
        switch cfg.level {
        case .desktop:  return "Sits on the desktop behind your windows — the classic widget feel."
        case .normal:   return "Behaves like an ordinary window in the stacking order."
        case .floating: return "Stays above every other window."
        }
    }

    private func numField(_ label: String, _ value: Binding<Double>) -> some View {
        HStack(spacing: 5) {
            Text(label).font(.caption).foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            TextField("", value: value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                // Pressing Return applies, so the Apply button is a convenience
                // rather than a step you can forget.
                .onSubmit { push() }
        }
    }

    private func push() {
        guard let p = PanelController.shared.panel(id) else { return }
        p.setFrameProgrammatically(cfg.frame.nsRect)
    }
}
