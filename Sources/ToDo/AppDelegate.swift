import AppKit
import SwiftUI
import Combine
import ServiceManagement

@main
enum ToDoMain {
    static func main() {
        Fonts.register()

        if CommandLine.arguments.contains("--test-right-click") {
            // title area, empty paper right of an item, an item, the footer
            let spots = [CGPoint(x: 70, y: 45), CGPoint(x: 250, y: 45), CGPoint(x: 290, y: 140),
                         CGPoint(x: 100, y: 108), CGPoint(x: 150, y: 215)]
            exit(MainActor.assumeIsolated { Render.rightClickTest(at: spots) } ? 0 : 1)
        }
        // Turns on "Open at login" without the menu — same call the menu makes.
        if CommandLine.arguments.contains("--open-at-login") {
            do {
                try SMAppService.mainApp.register()
                print("open at login: \(SMAppService.mainApp.status == .enabled ? "on" : "needs approval in System Settings → General → Login Items")")
                exit(0)
            } catch {
                print("open at login failed: \(error.localizedDescription)")
                exit(1)
            }
        }
        if CommandLine.arguments.contains("--test-edit") {
            exit(MainActor.assumeIsolated { Render.editTest() } ? 0 : 1)
        }
        if CommandLine.arguments.contains("--test-row-menu") {
            exit(MainActor.assumeIsolated { Render.rowMenuTest() } ? 0 : 1)
        }
        if CommandLine.arguments.contains("--test-picker-flow") {
            exit(MainActor.assumeIsolated { Render.pickerFlowTest() } ? 0 : 1)
        }
        if CommandLine.arguments.contains("--test-picker") {
            exit(MainActor.assumeIsolated { Render.pickerClickTest() } ? 0 : 1)
        }

        // Offscreen render for checking layout against the design system.
        if let i = CommandLine.arguments.firstIndex(of: "--render"),
           i + 1 < CommandLine.arguments.count {
            let dark = CommandLine.arguments.contains("--dark")
            if CommandLine.arguments.contains("--window") {
                exit(MainActor.assumeIsolated {
                    Render.window(to: CommandLine.arguments[i + 1], dark: dark)
                } ? 0 : 1)
            }
            if CommandLine.arguments.contains("--live") {
                exit(MainActor.assumeIsolated {
                    Render.live(to: CommandLine.arguments[i + 1], dark: dark)
                } ? 0 : 1)
            }
            if CommandLine.arguments.contains("--trigger") {
                exit(MainActor.assumeIsolated {
                    Render.trigger(to: CommandLine.arguments[i + 1], dark: dark)
                } ? 0 : 1)
            }
            exit(MainActor.assumeIsolated {
                Render.panel(to: CommandLine.arguments[i + 1], dark: dark)
            } ? 0 : 1)
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // A menu bar app: no Dock icon, no window in the switcher.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = Store()
    private let state = PanelState()
    private let panel = PanelWindow()
    private var statusItem: NSStatusItem!
    /// Clicking the glyph while the panel is down makes it resign key *before*
    /// the button's action runs, so a plain toggle would close and reopen.
    private var lastClosed = Date.distantPast
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !Fonts.complete {
            FileHandle.standardError.write(Data(
                "to do: Caveat / Shantell Sans are not in the bundle — falling back. Run Scripts/fetch-fonts.sh\n".utf8))
        }

        panel.delegate = self
        panel.onCancel = { [weak self] in self?.close() }

        buildStatusItem()
        GlobalHotKey.shared.register { [weak self] in self?.toggle() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotKey.shared.unregister()
    }

    // MARK: The glyph

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        let glyph = NSHostingView(rootView: StatusGlyphView(store: store, state: state))
        glyph.translatesAutoresizingMaskIntoConstraints = false
        // The button behind it takes every click; the SwiftUI view only draws.
        button.addSubview(glyph)
        NSLayoutConstraint.activate([
            glyph.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])

        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("to do")

        // The button carries no image or title, so it has no width of its own —
        // left to `variableLength` it collapses and squeezes the glyph. Size it
        // to the composite, and resize when the badge appears or goes.
        fitStatusItem()
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.fitStatusItem() }
            .store(in: &cancellables)
    }

    private func fitStatusItem() {
        let composite = StatusGlyphView.width(badge: store.openCount > 0)
        // A little air either side, the way the system's own extras sit.
        statusItem.length = composite + Tk.space2
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            toggle()
        }
    }

    private func showMenu() {
        close()

        let menu = NSMenu()

        let login = NSMenuItem(title: "Open at login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit to do",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Hand the button back, so the next left click opens the panel.
        statusItem.menu = nil
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Only works from a real .app bundle — see Scripts/make-app.sh.
            NSSound.beep()
        }
    }

    // MARK: The panel

    private func toggle() {
        if panel.isVisible {
            close()
        } else if Date().timeIntervalSince(lastClosed) > 0.25 {
            open()
        }
    }

    private func open() {
        guard let button = statusItem.button,
              let barWindow = button.window,
              let screen = barWindow.screen ?? NSScreen.main
        else { return }

        // A fresh view each time, so the note opens tilted and straightens as the
        // caret lands, and so the day is re-read if midnight has passed.
        let view = NSHostingView(rootView: PanelView(store: store) { [weak self] height in
            self?.resize(to: height)
        })
        view.frame = NSRect(x: 0, y: 0, width: Tk.panelWidth, height: 200)
        panel.contentView = view
        view.layoutSubtreeIfNeeded()

        let height = max(view.fittingSize.height, 120)
        let anchor = barWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = screen.visibleFrame
        let margin = Tk.space2

        var x = anchor.midX - Tk.panelWidth / 2
        x = min(max(x, visible.minX + margin), visible.maxX - Tk.panelWidth - margin)

        panel.setFrame(
            NSRect(x: x, y: anchor.minY - height - margin, width: Tk.panelWidth, height: height),
            display: true
        )
        // Hand first responder to the writing line before the window becomes
        // key. Left to AppKit it goes to the first focusable control — the top
        // checkbox — which shows its focus ring until the field takes over, and
        // reads as the first row flashing every time the panel opens.
        if let field = Self.writingLine(in: view) {
            panel.initialFirstResponder = field
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
        if let field = Self.writingLine(in: view) {
            panel.makeFirstResponder(field)
        }
        state.isOpen = true
    }

    /// The note's one text field, wherever SwiftUI has put it in the hierarchy.
    private static func writingLine(in view: NSView) -> NSTextField? {
        if let field = view as? CaretTextField { return field }
        for sub in view.subviews {
            if let found = writingLine(in: sub) { return found }
        }
        return nil
    }

    private func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        state.isOpen = false
        lastClosed = Date()
    }

    /// Follows the list as lines are added and cleared, keeping the top edge
    /// pinned to the menu bar.
    private func resize(to height: CGFloat) {
        guard panel.isVisible, height > 0 else { return }
        var frame = panel.frame
        guard abs(frame.height - height) > 0.5 else { return }
        frame.origin.y += frame.height - height
        frame.size.height = height
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    /// `--pin` keeps the panel down when it loses focus, so it can be
    /// screenshotted. The panel normally vanishes the moment you click away,
    /// which is the point of the app but makes it impossible to photograph.
    private let staysOpen = CommandLine.arguments.contains("--pin")

    // Click away and it is gone.
    func windowDidResignKey(_ notification: Notification) {
        guard !staysOpen else { return }
        close()
    }
}
