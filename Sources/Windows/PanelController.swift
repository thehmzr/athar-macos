import AppKit
import SwiftUI
import Combine

/// Per-widget live state: which quote is showing and the auto-shuffle timer.
final class WidgetRuntime: ObservableObject {
    let widgetID: UUID
    @Published private(set) var quote: Quote?

    private let engine = ShuffleEngine()
    private var timer: Timer?
    private var interval: ShuffleInterval = .manual

    init(widgetID: UUID) {
        self.widgetID = widgetID
        let cfg = AppSettings.shared.widget(widgetID) ?? WidgetConfig()
        engine.reset(to: cfg.lastQuoteIndex)
        quote = engine.current(from: QuoteLibrary.shared.pool(for: cfg))
        if quote == nil { shuffle(animated: false) }
        retimeIfNeeded()
    }

    deinit { timer?.invalidate() }

    func shuffle(animated: Bool = true) {
        guard let cfg = AppSettings.shared.widget(widgetID) else { return }
        let pool = QuoteLibrary.shared.pool(for: cfg)
        guard let next = engine.next(from: pool, order: cfg.shuffleOrder) else { return }
        let apply = { self.quote = next }
        // Reduce Motion keeps the cross-fade — which aids comprehension — but
        // drops the scale, which is the vestibular part.
        if animated && cfg.animateTransitions {
            let reduced = SystemPreferences.shared.reduceMotion
            withAnimation(.easeInOut(duration: reduced ? 0.22 : 0.35)) { apply() }
        } else {
            apply()
        }
        AppSettings.shared.update(widgetID) { $0.lastQuoteIndex = self.engine.currentIndex }
    }

    /// Re-reads the current pool without advancing — used when filters change.
    func refreshPool() {
        guard let cfg = AppSettings.shared.widget(widgetID) else { return }
        let pool = QuoteLibrary.shared.pool(for: cfg)
        if let q = quote, pool.contains(q) { return }
        quote = engine.current(from: pool) ?? pool.first
    }

    /// Rebuilds the timer only when the interval actually changed, so routine
    /// settings edits don't restart the countdown.
    func retimeIfNeeded() {
        guard let cfg = AppSettings.shared.widget(widgetID) else { return }
        guard cfg.shuffleInterval != interval else { return }
        interval = cfg.shuffleInterval
        timer?.invalidate(); timer = nil
        guard let secs = interval.seconds else { return }
        let t = Timer(timeInterval: secs, repeats: true) { [weak self] _ in
            self?.shuffle()
        }
        t.tolerance = min(secs * 0.1, 30)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}

/// Owns every on-screen panel and keeps them in sync with `AppSettings.widgets`.
final class PanelController {
    static let shared = PanelController()

    private var panels: [UUID: WidgetPanel] = [:]
    private var runtimes: [UUID: WidgetRuntime] = [:]
    private var bag = Set<AnyCancellable>()

    private init() {}

    func start() {
        sync()
        AppSettings.shared.$widgets
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.sync() }
            .store(in: &bag)
    }

    func runtime(_ id: UUID) -> WidgetRuntime {
        if let r = runtimes[id] { return r }
        let r = WidgetRuntime(widgetID: id)
        runtimes[id] = r
        return r
    }

    /// Creates, updates and tears down panels to match the configured widgets.
    func sync() {
        let configs = AppSettings.shared.widgets
        let live = Set(configs.map(\.id))

        for (id, panel) in panels where !live.contains(id) {
            panel.orderOut(nil)
            panels.removeValue(forKey: id)
            runtimes.removeValue(forKey: id)
        }

        for cfg in configs {
            if cfg.visible {
                let panel = panels[cfg.id] ?? make(cfg)
                // A locked widget's stored frame is authoritative: re-assert it
                // so nothing — a stale window frame, a relaunch, AppKit deciding
                // to grow the window — can drift it away from what the user set.
                // Only when locked, or this would fight an in-progress drag.
                if cfg.locked {
                    let want = clampToScreens(cfg.frame.nsRect)
                    if panel.frame != want { panel.setFrameProgrammatically(want) }
                }
                panel.apply(cfg)
                if !panel.isVisible { panel.orderFront(nil) }
            } else {
                panels[cfg.id]?.orderOut(nil)
            }
            runtimes[cfg.id]?.retimeIfNeeded()
            runtimes[cfg.id]?.refreshPool()
        }
    }

    private func make(_ cfg: WidgetConfig) -> WidgetPanel {
        let rect = clampToScreens(cfg.frame.nsRect)
        let panel = WidgetPanel(widgetID: cfg.id, contentRect: rect)
        panel.onFrameChange = { r in
            AppSettings.shared.updateFrameSilently(cfg.id, r)
        }
        panel.install(QuoteWidgetView(widgetID: cfg.id, runtime: runtime(cfg.id)))
        panels[cfg.id] = panel
        return panel
    }

    /// Keeps a restored frame on an attached display — monitors get unplugged.
    private func clampToScreens(_ rect: NSRect) -> NSRect {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return rect }
        if screens.contains(where: { $0.visibleFrame.intersects(rect) }) { return rect }
        let vf = (NSScreen.main ?? screens[0]).visibleFrame
        return NSRect(x: vf.midX - rect.width / 2, y: vf.midY - rect.height / 2,
                      width: rect.width, height: rect.height)
    }

    func shuffleAll() { runtimes.values.forEach { $0.shuffle() } }

    func panel(_ id: UUID) -> WidgetPanel? { panels[id] }

    /// Briefly brings a panel forward so the user can see which one they're editing.
    func flash(_ id: UUID, duration: TimeInterval = 1.1) {
        guard let p = panels[id] else { return }
        let restore = AppSettings.shared.widget(id)?.level ?? .desktop
        p.level = .floating
        p.orderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            // Read the level back from settings rather than capturing it — the
            // user may have changed it from the settings window meanwhile.
            p.level = (AppSettings.shared.widget(id)?.level ?? restore).windowLevel
        }
    }
}

extension WidgetRuntime {
    /// Forces a specific quote — used by the offscreen render harness.
    func setForPreview(_ q: Quote) { quote = q }
}
