import SwiftUI
import AppKit

struct LibraryTab: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var library = QuoteLibrary.shared

    @State private var search = ""
    @State private var scope: Scope = .all
    @State private var sourceFilter: QuoteSource? = nil

    @State private var showingEditor = false
    @State private var draft = Quote(text: "", author: "", categories: [], source: .modern,
                                     lang: .en, isCustom: true)
    @State private var editingID: String?

    @State private var showingNewCollection = false
    @State private var newCollectionName = ""

    enum Scope: Hashable {
        case all, favourites, mine, collection(UUID)
    }

    private var scopedQuotes: [Quote] {
        switch scope {
        case .all:        return library.allQuotes
        case .favourites: return library.allQuotes.filter { settings.favorites.contains($0.id) }
        case .mine:       return settings.customQuotes
        case .collection(let id):
            let ids = Set(settings.collection(id)?.quoteIDs ?? [])
            return library.allQuotes.filter { ids.contains($0.id) }
        }
    }

    private var filtered: [Quote] {
        var out = scopedQuotes
        if let s = sourceFilter { out = out.filter { $0.source == s } }
        guard !search.isEmpty else { return out }
        let q = search.lowercased()
        return out.filter {
            $0.text.lowercased().contains(q)
                || ($0.translation ?? "").lowercased().contains(q)
                || $0.author.lowercased().contains(q)
                || $0.categories.contains { c in
                    c.en.lowercased().contains(q) || c.ar.contains(search)
                }
                || $0.source.en.lowercased().contains(q) || $0.source.ar.contains(search)
        }
    }

    var body: some View {
        SectionCard(title: "Included content") {
            Text("Switch a source off to remove it from every widget and from "
                 + "this library. Nothing is deleted — turn it back on any time.")
                .font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 6)], spacing: 6) {
                ForEach(QuoteSource.allCases, id: \.self) { s in
                    let total = library.everyQuote.filter { $0.source == s }.count
                    let on = !settings.disabledSources.contains(s)
                    Button {
                        if on { settings.disabledSources.insert(s) }
                        else { settings.disabledSources.remove(s) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 11))
                                .foregroundStyle(on ? Color.accentColor : .secondary)
                            Text(s.en).font(.system(size: 11)).lineLimit(1)
                            Spacer(minLength: 2)
                            Text("\(total)").font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(on ? Color.primary.opacity(0.06) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(.secondary.opacity(on ? 0 : 0.35), lineWidth: 1))
                        .opacity(on ? 1 : 0.55)
                    }.buttonStyle(.plain)
                }
            }
            HStack {
                if !settings.disabledSources.isEmpty {
                    Text("\(settings.disabledSources.count) source"
                         + (settings.disabledSources.count == 1 ? "" : "s") + " hidden — "
                         + "\(library.allQuotes.count) of \(library.everyQuote.count) quotes in use")
                        .font(.caption).foregroundStyle(.orange)
                } else {
                    Text("All \(library.everyQuote.count) quotes in use.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Include all") { settings.disabledSources = [] }
                    .font(.caption)
                    .disabled(settings.disabledSources.isEmpty)
            }
        }

        SectionCard(title: "Collections") {
            HStack(spacing: 6) {
                scopeButton("All", "tray.full", .all, library.allQuotes.count)
                scopeButton("Favourites", "heart", .favourites, settings.favorites.count)
                scopeButton("My quotes", "square.and.pencil", .mine, settings.customQuotes.count)
            }
            if !settings.collections.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], spacing: 6) {
                    ForEach(settings.collections) { c in
                        scopeButton(c.name, c.symbol, .collection(c.id), c.quoteIDs.count)
                            .contextMenu {
                                Button("Delete \u{201C}\(c.name)\u{201D}", role: .destructive) {
                                    if scope == .collection(c.id) { scope = .all }
                                    settings.removeCollection(c.id)
                                }
                            }
                    }
                }
            }
            Button {
                newCollectionName = ""; showingNewCollection = true
            } label: { Label("New collection", systemImage: "folder.badge.plus") }
                .font(.caption)
        }

        SectionCard(title: "Browse") {
            HStack {
                TextField("Search text, author, category or source…", text: $search)
                    .textFieldStyle(.roundedBorder)
                Button {
                    draft = Quote(text: "", author: "", categories: [], source: .modern,
                                  lang: .en, isCustom: true)
                    editingID = nil; showingEditor = true
                } label: { Label("Add", systemImage: "plus") }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    sourcePill(nil, "All sources")
                    ForEach(QuoteSource.allCases, id: \.self) { s in
                        sourcePill(s, s.en)
                    }
                }
            }

            Text("\(filtered.count) quotes")
                .font(.caption).foregroundStyle(.secondary)

            LazyVStack(spacing: 6) {
                ForEach(filtered) { q in row(q) }
            }
        }
        .sheet(isPresented: $showingEditor) { editor }
        .sheet(isPresented: $showingNewCollection) { newCollectionSheet }
    }

    // MARK: - Chrome

    private func scopeButton(_ title: String, _ symbol: String,
                             _ s: Scope, _ count: Int) -> some View {
        Button { scope = s } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 10))
                Text(title).font(.system(size: 11)).lineLimit(1)
                Spacer(minLength: 2)
                Text("\(count)").font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(scope == s ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain)
    }

    private func sourcePill(_ s: QuoteSource?, _ title: String) -> some View {
        Button { sourceFilter = s } label: {
            Text(title)
                .font(.system(size: 10))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(sourceFilter == s ? Color.accentColor.opacity(0.3)
                                              : Color.primary.opacity(0.06),
                            in: Capsule())
        }.buttonStyle(.plain)
    }

    private func row(_ q: Quote) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: q.lang.isRTL ? .trailing : .leading, spacing: 4) {
                Text(q.text)
                    .font(Font(FontCatalog.font(
                        family: q.lang.isRTL ? "Amiri" : FontCatalog.systemFamilySentinel,
                        size: q.lang.isRTL ? 16 : 12.5)))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(q.lang.isRTL ? .trailing : .leading)

                if let t = q.translation, !t.isEmpty {
                    Text(t)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .environment(\.layoutDirection, .leftToRight)
                }

                HStack(spacing: 5) {
                    if !q.author.isEmpty {
                        Text(q.author).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    badge(q.lang.isRTL ? q.source.ar : q.source.en,
                          tint: Color.accentColor.opacity(0.22))
                    ForEach(q.categories, id: \.self) { c in
                        badge(q.lang.isRTL ? c.ar : c.en, tint: Color.primary.opacity(0.07))
                    }
                    if q.isCustom {
                        badge("mine", tint: .green.opacity(0.25))
                    }
                    ForEach(settings.collections(containing: q)) { c in
                        badge(c.name, tint: .orange.opacity(0.22))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: q.lang.isRTL ? .trailing : .leading)
            .environment(\.layoutDirection, q.lang.isRTL ? .rightToLeft : .leftToRight)

            VStack(spacing: 4) {
                Button { settings.toggleFavorite(q) } label: {
                    Image(systemName: settings.isFavorite(q) ? "heart.fill" : "heart")
                        .foregroundStyle(settings.isFavorite(q) ? .red : .secondary)
                }.buttonStyle(.borderless)

                Menu {
                    if settings.collections.isEmpty {
                        Text("No collections yet")
                    }
                    ForEach(settings.collections) { c in
                        Button {
                            settings.toggle(q, inCollection: c.id)
                        } label: {
                            Label(c.name,
                                  systemImage: settings.isIn(q, collection: c.id)
                                    ? "checkmark.circle.fill" : "circle")
                        }
                    }
                    Divider()
                    Button("New collection…") {
                        newCollectionName = ""; pendingQuote = q; showingNewCollection = true
                    }
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 22)

                if q.isCustom {
                    Button {
                        draft = q; editingID = q.id; showingEditor = true
                    } label: { Image(systemName: "pencil") }.buttonStyle(.borderless)
                    Button {
                        settings.customQuotes.removeAll { $0.id == q.id }
                    } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                }
            }
            .font(.system(size: 11))
        }
        .padding(9)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(tint, in: Capsule())
    }

    // MARK: - Sheets

    /// Set when "New collection…" is chosen from a quote's folder menu, so the
    /// quote lands in the collection as soon as it is created.
    @State private var pendingQuote: Quote?

    private var newCollectionSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New collection").font(.headline)
            TextField("Name", text: $newCollectionName)
            if let q = pendingQuote {
                Text("\u{201C}\(q.text.prefix(48))…\u{201D} will be added to it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancel") { showingNewCollection = false; pendingQuote = nil }
                Spacer()
                Button("Create") {
                    let name = newCollectionName.trimmingCharacters(in: .whitespaces)
                    let c = settings.addCollection(named: name.isEmpty ? "Untitled" : name)
                    if let q = pendingQuote { settings.toggle(q, inCollection: c.id) }
                    pendingQuote = nil
                    showingNewCollection = false
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 380)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(editingID == nil ? "New quote" : "Edit quote").font(.headline)

            Picker("Language", selection: $draft.lang) {
                ForEach(Language.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }.pickerStyle(.segmented)

            Text("Quote").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $draft.text)
                .font(Font(FontCatalog.font(
                    family: draft.lang.isRTL ? "Amiri" : FontCatalog.systemFamilySentinel,
                    size: draft.lang.isRTL ? 18 : 13)))
                .environment(\.layoutDirection, draft.lang.isRTL ? .rightToLeft : .leftToRight)
                .frame(height: 92)
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.secondary.opacity(0.3)))

            TextField("Author", text: $draft.author)

            if draft.lang == .ar {
                TextField("English meaning (optional)", text: Binding(
                    get: { draft.translation ?? "" },
                    set: { draft.translation = $0.isEmpty ? nil : $0 }))
            }

            Picker("Source", selection: $draft.source) {
                ForEach(QuoteSource.allCases, id: \.self) { Text($0.en).tag($0) }
            }

            Text("Categories").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 5)], spacing: 5) {
                ForEach(QuoteCategory.allCases, id: \.self) { c in
                    let on = draft.categories.contains(c)
                    Button {
                        if let i = draft.categories.firstIndex(of: c) {
                            draft.categories.remove(at: i)
                        } else { draft.categories.append(c) }
                    } label: {
                        Text(draft.lang.isRTL ? c.ar : c.en)
                            .font(.system(size: 10)).lineLimit(1)
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(on ? Color.accentColor.opacity(0.28)
                                           : Color.primary.opacity(0.06), in: Capsule())
                    }.buttonStyle(.plain)
                }
            }

            HStack {
                Button("Cancel") { showingEditor = false }
                Spacer()
                Button(editingID == nil ? "Add" : "Save") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 470)
    }

    private func commit() {
        var q = draft
        q.isCustom = true
        q.text = q.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.categories.isEmpty { q.categories = [.wisdom] }
        if let editingID, let i = settings.customQuotes.firstIndex(where: { $0.id == editingID }) {
            settings.customQuotes[i] = q
        } else {
            settings.customQuotes.append(q)
        }
        showingEditor = false
    }
}
