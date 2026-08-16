import AppKit
import SwiftUI

/// Borderless panel that hosts one quote widget.
///
/// Borderless windows get no system resize handles, so resizing and dragging
/// are implemented by `PanelChromeView`, a transparent overlay that claims hits
/// only in the edge bands and the top drag strip and passes everything else
/// through to the SwiftUI content beneath.
final class WidgetPanel: NSPanel {

    let widgetID: UUID
    var onFrameChange: ((NSRect) -> Void)?
    private(set) var chrome: PanelChromeView!

    static let minSize = NSSize(width: 160, height: 110)

    /// Set while the app itself is moving the window, so a programmatic frame
    /// change is not mistaken for the user resizing and written back.
    private var applyingFrame = false
    private var persistWork: DispatchWorkItem?

    init(widgetID: UUID, contentRect: NSRect) {
        self.widgetID = widgetID
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .resizable, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false            // drawn in SwiftUI so it follows the corner radius
        isMovableByWindowBackground = true
        minSize = Self.minSize
        animationBehavior = .none
        // A borderless panel would otherwise be excluded from window lists and
        // never restore its frame correctly.
        isReleasedWhenClosed = false
        delegate = self
    }

    /// Moves the window without treating it as a user edit.
    func setFrameProgrammatically(_ rect: NSRect) {
        applyingFrame = true
        setFrame(rect, display: true)
        applyingFrame = false
    }

    /// Records the live frame after a move or resize, whoever performed it.
    ///
    /// The chrome overlay only sees the resizes it handles itself; AppKit's own
    /// `.resizable` edge behaviour bypasses it entirely, which left the stored
    /// frame stale — so locking afterwards snapped the panel back to an old
    /// size. Watching the window's own notifications catches both paths.
    fileprivate func schedulePersist() {
        guard !applyingFrame else { return }
        persistWork?.cancel()
        // Move and resize notifications fire continuously during a drag;
        // coalesce so the settings graph is not republished per frame.
        let w = DispatchWorkItem { [weak self] in
            guard let self, !self.applyingFrame else { return }
            self.onFrameChange?(self.frame)
        }
        persistWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: w)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Installs the SwiftUI content plus the chrome overlay above it.
    func install<Content: View>(_ view: Content) {
        let host = NSHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false
        // Without this the hosting view reports the SwiftUI content's intrinsic
        // size, and because it is pinned to all four edges of a resizable
        // window, AutoLayout grows the panel to fit a long verse. The panel
        // size is the user's choice; the text fits itself to the panel.
        host.sizingOptions = []

        let container = NSView(frame: contentRect(forFrameRect: frame))
        container.addSubview(host)

        let chrome = PanelChromeView(panel: self)
        chrome.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chrome)
        self.chrome = chrome

        contentView = container
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            chrome.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            chrome.topAnchor.constraint(equalTo: container.topAnchor),
            chrome.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    func apply(_ cfg: WidgetConfig) {
        level = cfg.level.windowLevel
        alphaValue = cfg.windowOpacity
        ignoresMouseEvents = cfg.clickThrough
        collectionBehavior = cfg.stickyAllSpaces
            ? [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            : [.stationary, .ignoresCycle, .fullScreenAuxiliary]
        chrome?.locked = cfg.locked
        // Background dragging bypasses the chrome overlay entirely, so it has to
        // be disabled too or a "locked" widget would still slide around.
        isMovableByWindowBackground = !cfg.locked
        applyLock(cfg)
        applyAppearance(cfg.theme)
    }

    /// Locking has to reach AppKit, not just the chrome overlay.
    ///
    /// `.resizable` in the style mask gives the window its own edge-resize
    /// behaviour, which is entirely independent of `PanelChromeView` — so with
    /// only the overlay disabled, a "locked" widget could still be resized by
    /// dragging its edges. Pinning min == max is what actually stops it.
    private func applyLock(_ cfg: WidgetConfig) {
        if cfg.locked {
            let s = frame.size
            minSize = s
            maxSize = s
            styleMask.remove(.resizable)
        } else {
            minSize = Self.minSize
            maxSize = NSSize(width: 100_000, height: 100_000)
            styleMask.insert(.resizable)
        }
    }

    /// `NSVisualEffectView` follows the window's appearance, but the theme's
    /// text colour does not — so a light-text palette over a glass panel in
    /// Light Mode renders white on white. Pin the appearance to whichever side
    /// the palette was designed for.
    private func applyAppearance(_ theme: Theme) {
        guard theme.background == .glass else { appearance = nil; return }
        if theme.glassFollowsSystem {
            // Inherit, so the material tracks Light/Dark. The text palette
            // swaps alongside it in the view — both must move together or this
            // is the white-on-white bug again.
            appearance = nil
            return
        }
        let wantsDarkSurface = theme.textColor.luminance > 0.5
        appearance = NSAppearance(named: wantsDarkSurface ? .darkAqua : .aqua)
    }

    func commitFrame() { onFrameChange?(frame) }
}

extension WidgetPanel: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) { schedulePersist() }
    func windowDidEndLiveResize(_ notification: Notification) { schedulePersist() }
    func windowDidMove(_ notification: Notification) { schedulePersist() }
}

/// Transparent overlay providing resize bands, a drag strip and cursor feedback.
final class PanelChromeView: NSView {

    enum Zone {
        case none, move
        case left, right, top, bottom
        case topLeft, topRight, bottomLeft, bottomRight

        var isResize: Bool { self != .none && self != .move }
    }

    private weak var panel: WidgetPanel?
    var locked: Bool = false { didSet { window?.invalidateCursorRects(for: self) } }

    /// Width of the grab band along each edge.
    private let band: CGFloat = 9
    /// Height of the strip at the top of the panel that drags the window.
    private let dragStrip: CGFloat = 30

    private var dragOrigin: NSPoint = .zero
    private var startFrame: NSRect = .zero
    private var activeZone: Zone = .none
    private var trackingArea: NSTrackingArea?

    init(panel: WidgetPanel) {
        self.panel = panel
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Hit testing

    /// Claim only the chrome regions; everything else falls through to SwiftUI.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !locked else { return nil }
        let local = convert(point, from: superview)
        return zone(at: local) == .none ? nil : self
    }

    private func zone(at p: NSPoint) -> Zone {
        let b = bounds
        guard b.contains(p) else { return .none }
        // AppKit origin is bottom-left.
        let nearL = p.x <= band
        let nearR = p.x >= b.maxX - band
        let nearB = p.y <= band
        let nearT = p.y >= b.maxY - band

        switch (nearL, nearR, nearB, nearT) {
        case (true, _, true, _):  return .bottomLeft
        case (_, true, true, _):  return .bottomRight
        case (true, _, _, true):  return .topLeft
        case (_, true, _, true):  return .topRight
        case (true, _, _, _):     return .left
        case (_, true, _, _):     return .right
        case (_, _, true, _):     return .bottom
        case (_, _, _, true):     return .top
        default: break
        }
        if p.y >= b.maxY - dragStrip { return .move }
        return .none
    }

    // MARK: - Cursors

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds,
                               options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                               owner: self, userInfo: nil)
        addTrackingArea(t)
        trackingArea = t
    }

    override func mouseMoved(with event: NSEvent) {
        guard !locked else { return }
        cursor(for: zone(at: convert(event.locationInWindow, from: nil))).set()
    }

    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

    private func cursor(for z: Zone) -> NSCursor {
        switch z {
        case .left, .right:   return .resizeLeftRight
        case .top, .bottom:   return .resizeUpDown
        // AppKit ships no public diagonal resize cursor; the crosshair reads
        // clearly as "resize from this corner".
        case .topLeft, .bottomRight, .topRight, .bottomLeft: return .crosshair
        case .move:           return .openHand
        case .none:           return .arrow
        }
    }

    // MARK: - Drag handling

    override func mouseDown(with event: NSEvent) {
        guard !locked, let panel else { return }
        let local = convert(event.locationInWindow, from: nil)
        activeZone = zone(at: local)
        dragOrigin = NSEvent.mouseLocation
        startFrame = panel.frame
        if activeZone == .move { NSCursor.closedHand.set() }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !locked, let panel, activeZone != .none else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - dragOrigin.x
        let dy = now.y - dragOrigin.y

        if activeZone == .move {
            panel.setFrameOrigin(NSPoint(x: startFrame.origin.x + dx,
                                         y: startFrame.origin.y + dy))
            return
        }

        var f = startFrame
        let minW = WidgetPanel.minSize.width
        let minH = WidgetPanel.minSize.height

        switch activeZone {
        case .left, .topLeft, .bottomLeft:
            let newW = max(minW, startFrame.width - dx)
            f.origin.x = startFrame.maxX - newW
            f.size.width = newW
        case .right, .topRight, .bottomRight:
            f.size.width = max(minW, startFrame.width + dx)
        default: break
        }

        switch activeZone {
        case .bottom, .bottomLeft, .bottomRight:
            let newH = max(minH, startFrame.height - dy)
            f.origin.y = startFrame.maxY - newH
            f.size.height = newH
        case .top, .topLeft, .topRight:
            f.size.height = max(minH, startFrame.height + dy)
        default: break
        }

        panel.setFrame(f, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        activeZone = .none
        NSCursor.arrow.set()
        panel?.commitFrame()
    }
}

/// NSVisualEffectView bridged for the "Glass" background style.
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material }
}
