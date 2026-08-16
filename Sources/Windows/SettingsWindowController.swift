import AppKit
import SwiftUI

/// Hosts the SwiftUI settings UI in a normal titled window.
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "Athar"
        w.isReleasedWhenClosed = false
        w.center()
        super.init(window: w)
    }
    required init?(coder: NSCoder) { fatalError() }

    func show(selecting id: UUID?) {
        let selection = id ?? AppSettings.shared.widgets.first?.id ?? UUID()
        window?.contentView = NSHostingView(rootView: SettingsView(selection: selection))
        // An .accessory app must activate explicitly or the window opens behind.
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
