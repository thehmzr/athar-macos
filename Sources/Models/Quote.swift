import Foundation

/// Topic. Bilingual by construction, so selecting "Wisdom" also matches
/// Arabic wisdom quotes — the previous free-string tags could not do that,
/// because "Wisdom" and "حكمة" were unrelated strings.
enum QuoteCategory: String, Codable, CaseIterable, Hashable {
    case faith, wisdom, motivation, life, knowledge, patience
    case love, success, work, time, selfhood, friendship, hope

    var en: String {
        switch self {
        case .faith: return "Faith";           case .wisdom: return "Wisdom"
        case .motivation: return "Motivation"; case .life: return "Life"
        case .knowledge: return "Knowledge";   case .patience: return "Patience"
        case .love: return "Love";             case .success: return "Success"
        case .work: return "Work";             case .time: return "Time"
        case .selfhood: return "Self";         case .friendship: return "Friendship"
        case .hope: return "Hope"
        }
    }

    var ar: String {
        switch self {
        case .faith: return "إيمان";        case .wisdom: return "حكمة"
        case .motivation: return "تحفيز";   case .life: return "حياة"
        case .knowledge: return "علم";      case .patience: return "صبر"
        case .love: return "حب";            case .success: return "نجاح"
        case .work: return "عمل";           case .time: return "وقت"
        case .selfhood: return "نفس";       case .friendship: return "صداقة"
        case .hope: return "أمل"
        }
    }

    var symbol: String {
        switch self {
        case .faith: return "moon.stars";        case .wisdom: return "brain.head.profile"
        case .motivation: return "flame";        case .life: return "leaf"
        case .knowledge: return "book";          case .patience: return "hourglass"
        case .love: return "heart";              case .success: return "trophy"
        case .work: return "hammer";             case .time: return "clock"
        case .selfhood: return "person";         case .friendship: return "person.2"
        case .hope: return "sunrise"
        }
    }
}

/// Where a quote comes from — a different axis from topic. A verse can be
/// about patience and a proverb can be about patience; the source separates them.
enum QuoteSource: String, Codable, CaseIterable, Hashable {
    case quran, hadith, poetry, proverb, classical, philosophy, literature, modern

    var en: String {
        switch self {
        case .quran: return "Qur'an";          case .hadith: return "Hadith"
        case .poetry: return "Poetry";         case .proverb: return "Proverbs"
        case .classical: return "Classical";   case .philosophy: return "Philosophy"
        case .literature: return "Literature"; case .modern: return "Modern"
        }
    }

    var ar: String {
        switch self {
        case .quran: return "قرآن";         case .hadith: return "حديث"
        case .poetry: return "شعر";         case .proverb: return "أمثال"
        case .classical: return "تراث";     case .philosophy: return "فلسفة"
        case .literature: return "أدب";     case .modern: return "معاصر"
        }
    }

    var symbol: String {
        switch self {
        case .quran: return "book.closed";       case .hadith: return "text.book.closed"
        case .poetry: return "music.quarternote.3"; case .proverb: return "quote.opening"
        case .classical: return "scroll";        case .philosophy: return "building.columns"
        case .literature: return "books.vertical"; case .modern: return "sparkles"
        }
    }

    /// Sources that only exist in Arabic — hidden when the widget is English-only.
    var isArabicOnly: Bool { self == .quran || self == .hadith || self == .classical }
}

struct Quote: Codable, Identifiable, Hashable {
    var id: String { "\(lang.rawValue)|\(author)|\(text.prefix(40))" }

    var text: String
    var author: String
    var categories: [QuoteCategory]
    var source: QuoteSource
    var lang: Language = .en
    /// English rendering of the meaning, for Arabic scripture. Nil for quotes
    /// that are already in the reader's language.
    var translation: String? = nil
    /// User-authored quotes are editable and deletable; bundled ones are not.
    var isCustom: Bool = false

    enum CodingKeys: String, CodingKey {
        case text, author, categories, source, lang, translation, isCustom
    }

    init(text: String, author: String, categories: [QuoteCategory],
         source: QuoteSource = .modern, lang: Language = .en,
         translation: String? = nil, isCustom: Bool = false) {
        self.text = text; self.author = author; self.categories = categories
        self.source = source; self.lang = lang
        self.translation = translation; self.isCustom = isCustom
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        categories = try c.decodeIfPresent([QuoteCategory].self, forKey: .categories) ?? []
        source = try c.decodeIfPresent(QuoteSource.self, forKey: .source) ?? .modern
        lang = try c.decodeIfPresent(Language.self, forKey: .lang) ?? .en
        translation = try c.decodeIfPresent(String.self, forKey: .translation)
        isCustom = try c.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
    }

    var hasTranslation: Bool {
        !(translation ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Category names in the quote's own language.
    func categoryLabels(_ lang: Language) -> [String] {
        categories.map { lang.isRTL ? $0.ar : $0.en }
    }
}

enum Language: String, Codable, CaseIterable, Hashable {
    case en, ar

    var isRTL: Bool { self == .ar }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ar: return "العربية"
        }
    }
}

/// Which pool the shuffler draws from.
enum LanguageMode: String, Codable, CaseIterable, Hashable {
    case english, arabic, both

    var displayName: String {
        switch self {
        case .english: return "English"
        case .arabic:  return "العربية"
        case .both:    return "Both"
        }
    }

    func includes(_ l: Language) -> Bool {
        switch self {
        case .english: return l == .en
        case .arabic:  return l == .ar
        case .both:    return true
        }
    }
}

/// A user-named folder of quotes, saved alongside settings.
struct QuoteCollection: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var quoteIDs: [String] = []
    /// SF Symbol shown beside the collection in the sidebar.
    var symbol: String = "folder"

    func contains(_ q: Quote) -> Bool { quoteIDs.contains(q.id) }
}
