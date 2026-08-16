import SwiftUI
import AppKit

let out = FileManager.default.currentDirectoryPath + "/build/preview"
RenderHarness.registerFonts(FileManager.default.currentDirectoryPath + "/Resources/Fonts")

try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

DispatchQueue.main.async {
    // Font specimen sheet
    RenderHarness.write(RenderHarness.Specimen(), size: CGSize(width: 760, height: 1500),
                        to: "\(out)/specimen.png")

    // Real widget at several sizes / themes / languages
    var cfgs: [(String, WidgetConfig, CGSize, Quote)] = []

    let arQuote = Quote(text: "على قدر أهل العزم تأتي العزائمُ، وتأتي على قدر الكرام المكارمُ.",
                        author: "المتنبي", categories: [.success], source: .poetry, lang: .ar)
    let enQuote = Quote(text: "Simplicity is the ultimate sophistication.",
                        author: "Leonardo da Vinci", categories: [.wisdom], source: .modern, lang: .en)
    // Qur'anic text carries full tashkeel — the heaviest diacritic load the
    // renderer will ever see, so it is worth checking explicitly.
    let quran = Quote(text: "وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ",
                      author: "سورة البقرة: ٢١٦", categories: [.faith], source: .quran, lang: .ar)
    let hadith = Quote(text: "مَنْ سَلَكَ طَرِيقًا يَلْتَمِسُ فِيهِ عِلْمًا سَهَّلَ اللَّهُ لَهُ بِهِ طَرِيقًا إِلَى الْجَنَّةِ",
                       author: "رواه مسلم", categories: [.knowledge], source: .hadith, lang: .ar)

    var a = WidgetConfig(); a.theme = Theme.presets[0]; a.arabicFont = "Amiri"
    cfgs.append(("w_amiri_medium", a, CGSize(width: 420, height: 300), arQuote))

    var b = WidgetConfig(); b.theme = Theme.presets[8]; b.arabicFont = "Aref Ruqaa"
    cfgs.append(("w_ruqaa_mushaf", b, CGSize(width: 620, height: 300), arQuote))

    var c = WidgetConfig(); c.theme = Theme.presets[3]; c.arabicFont = "Noto Nastaliq Urdu"
    cfgs.append(("w_nastaliq_desert", c, CGSize(width: 560, height: 340), arQuote))

    var d = WidgetConfig(); d.theme = Theme.presets[1]; d.latinFont = FontCatalog.serifSentinel
    cfgs.append(("w_en_parchment", d, CGSize(width: 420, height: 260), enQuote))

    var e = WidgetConfig(); e.theme = Theme.presets[0]; e.arabicFont = "Reem Kufi"
    cfgs.append(("w_kufi_small", e, CGSize(width: 240, height: 190), arQuote))

    var f = WidgetConfig(); f.theme = Theme.presets[4]; f.arabicFont = "Amiri"
    cfgs.append(("w_amiri_banner", f, CGSize(width: 820, height: 200), arQuote))

    var g = WidgetConfig(); g.theme = Theme.presets[8]; g.arabicFont = "Amiri"
    cfgs.append(("w_quran_amiri", g, CGSize(width: 520, height: 260), quran))
    var h = WidgetConfig(); h.theme = Theme.presets[7]; h.arabicFont = "Scheherazade New"
    cfgs.append(("w_hadith_scheh", h, CGSize(width: 560, height: 320), hadith))
    var i2 = WidgetConfig(); i2.theme = Theme.presets[2]; i2.arabicFont = "Noto Naskh Arabic"
    cfgs.append(("w_quran_naskh", i2, CGSize(width: 400, height: 240), quran))

    // Prove the toggle works in both directions, not just that the default moved.
    var m1 = WidgetConfig(); m1.theme = Theme.presets[0]; m1.arabicFont = "Amiri"
    m1.showQuoteMarks = false
    cfgs.append(("marks_off_ar", m1, CGSize(width: 460, height: 260), arQuote))
    var m2 = WidgetConfig(); m2.theme = Theme.presets[0]; m2.arabicFont = "Amiri"
    m2.showQuoteMarks = true
    cfgs.append(("marks_on_ar", m2, CGSize(width: 460, height: 260), arQuote))
    var m3 = WidgetConfig(); m3.theme = Theme.presets[1]; m3.latinFont = FontCatalog.serifSentinel
    m3.showQuoteMarks = false
    cfgs.append(("marks_off_en", m3, CGSize(width: 460, height: 230), enQuote))

    let motiv = Quote(text: "وَلَا تَهِنُوا وَلَا تَحْزَنُوا وَأَنتُمُ الْأَعْلَوْنَ إِن كُنتُم مُّؤْمِنِينَ",
                      author: "سورة آل عمران: ١٣٩", categories: [.motivation], source: .quran, lang: .ar)
    var mv = WidgetConfig(); mv.theme = Theme.presets[7]; mv.arabicFont = "Amiri"
    cfgs.append(("w_motivation_quran", mv, CGSize(width: 620, height: 300), motiv))

    // Translation on, at a comfortable size and at a size small enough that it
    // should be dropped rather than crushing the verse.
    let tq = Quote(text: "وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ",
                   author: "سورة البقرة: ٢١٦", categories: [.faith], source: .quran, lang: .ar,
                   translation: "Perhaps you dislike a thing, and it is good for you.")
    var t1 = WidgetConfig(); t1.theme = Theme.presets[8]; t1.arabicFont = "Amiri"
    cfgs.append(("w_trans_medium", t1, CGSize(width: 520, height: 300), tq))
    var t2 = WidgetConfig(); t2.theme = Theme.presets[7]; t2.arabicFont = "Amiri"
    cfgs.append(("w_trans_large", t2, CGSize(width: 700, height: 340), tq))
    var t3 = WidgetConfig(); t3.theme = Theme.presets[0]; t3.arabicFont = "Amiri"
    cfgs.append(("w_trans_tiny", t3, CGSize(width: 210, height: 150), tq))
    var t4 = WidgetConfig(); t4.theme = Theme.presets[8]; t4.arabicFont = "Amiri"
    t4.showTranslation = false
    cfgs.append(("w_trans_off", t4, CGSize(width: 520, height: 300), tq))

    // Alignment + translation: does the gloss follow the verse's edge?
    let aq = Quote(text: "وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ",
                   author: "سورة البقرة: ٢١٦", categories: [.faith], source: .quran, lang: .ar,
                   translation: "Perhaps you dislike a thing, and it is good for you.")
    var al = WidgetConfig(); al.theme = Theme.presets[8]; al.arabicFont = "Amiri"
    al.alignment = .leading
    cfgs.append(("w_align_leading", al, CGSize(width: 560, height: 300), aq))
    var at = WidgetConfig(); at.theme = Theme.presets[8]; at.arabicFont = "Amiri"
    at.alignment = .trailing
    cfgs.append(("w_align_trailing", at, CGSize(width: 560, height: 300), aq))

    let shortQ = Quote(text: "الطُّهُورُ شَطْرُ الإِيمَانِ", author: "رواه مسلم",
                       categories: [.faith], source: .hadith, lang: .ar,
                       translation: "Cleanliness is half of faith.")
    var sl = WidgetConfig(); sl.theme = Theme.presets[9]; sl.arabicFont = "Amiri"
    sl.alignment = .leading
    cfgs.append(("w_short_leading", sl, CGSize(width: 620, height: 260), shortQ))

    let longQ = Quote(text: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً",
                      author: "سورة البقرة: ٢٠١", categories: [.faith], source: .quran, lang: .ar,
                      translation: "Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.")
    var ml = WidgetConfig(); ml.theme = Theme.presets[9]; ml.arabicFont = "Amiri"
    ml.alignment = .leading
    cfgs.append(("w_multiline_leading", ml, CGSize(width: 470, height: 330), longQ))

    // Uthmani script uses glyphs plain Arabic does not (ٱ alef wasla, ۟ small
    // high rounded zero, ۖ pause marks). Verify the faces actually render them.
    let uth = Quote(text: "إِنَّ مَعَ ٱلْعُسْرِ يُسْرًا", author: "سورة الشرح: ٦",
                    categories: [.faith], source: .quran, lang: .ar,
                    translation: "Indeed, with hardship [will be] ease.")
    var u1 = WidgetConfig(); u1.theme = Theme.presets[8]; u1.arabicFont = "Amiri"
    cfgs.append(("w_uthmani_amiri", u1, CGSize(width: 560, height: 300), uth))
    let uth2 = Quote(text: "وَعَسَىٰٓ أَن تَكْرَهُوا۟ شَيْـًٔا وَهُوَ خَيْرٌ لَّكُمْ ۖ",
                     author: "سورة البقرة: ٢١٦", categories: [.faith], source: .quran, lang: .ar,
                     translation: "Perhaps you dislike a thing and it is good for you.")
    var u2 = WidgetConfig(); u2.theme = Theme.presets[9]; u2.arabicFont = "Scheherazade New"
    cfgs.append(("w_uthmani_scheh", u2, CGSize(width: 620, height: 320), uth2))

    let sv = Quote(text: "وَإِذَا مَرِضْتُ فَهُوَ يَشْفِينِ", author: "سورة الشعراء: ٨٠",
                   categories: [.faith], source: .quran, lang: .ar,
                   translation: "And when I am ill, it is he who cures me.")
    var s1 = WidgetConfig(); s1.theme = Theme.presets[8]; s1.arabicFont = "Amiri"
    cfgs.append(("w_short_verse", s1, CGSize(width: 460, height: 260), sv))

    for (name, cfg, size, q) in cfgs {
        AppSettings.shared.widgets = [cfg]
        let rt = PanelController.shared.runtime(cfg.id)
        rt.setForPreview(q)
        let v = QuoteWidgetView(widgetID: cfg.id, runtime: rt)
        RenderHarness.write(v, size: size, to: "\(out)/\(name).png")
    }
    exit(0)
}
app.run()
