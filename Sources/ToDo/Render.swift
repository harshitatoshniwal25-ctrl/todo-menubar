import SwiftUI
import AppKit

/// `to do --render <path.png>` draws the panel offscreen and exits.
///
/// There is no other way to actually look at a menu bar panel: it closes the
/// moment it loses key, so it cannot be screenshotted from a script. This
/// renders it with sample content — never the real note — so the layout can be
/// checked against the design system without guessing from a cropped photo.
enum Render {
    /// The five trigger states in a row, laid out like the design system's own
    /// preview card, so the two can be measured against each other.
    @MainActor
    static func trigger(to path: String, dark: Bool = true) -> Bool {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        NSApplication.shared.appearance = appearance
        appearance.map { NSAppearance.current = $0 }

        let states: [(String, Bool, Int, Tk.Paper)] = [
            ("idle", false, 0, .butter),
            ("panel open", true, 0, .butter),
            ("4 left", false, 4, .butter),
            ("pink note", false, 7, .rose),
        ]

        let row = HStack(spacing: 48) {
            ForEach(states, id: \.0) { name, open, count, paper in
                VStack(spacing: 14) {
                    TriggerPreview(open: open, count: count, paper: paper)
                    Text(name).textStyle(.meta).foregroundStyle(Tk.chromeInkMuted)
                }
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 40)
        .background(Tk.surfaceDesk)
        .environment(\.colorScheme, dark ? .dark : .light)

        let renderer = ImageRenderer(content: row)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return false }
        try? png.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write(Data("rendered \(rep.pixelsWide)x\(rep.pixelsHigh) to \(path)\n".utf8))
        return true
    }

    /// Same panel, but drawn through a real NSWindow instead of ImageRenderer.
    ///
    /// This matters: ImageRenderer draws the whole tree into one context, so ink
    /// that overhangs a view's layout bounds still lands. A live window backs
    /// each Text with its own layer sized to the *advance* width, and a face
    /// whose last glyph inks past that gets its tail cut. Only this path shows
    /// what is actually on screen.
    @MainActor
    static func window(to path: String, dark: Bool = false) -> Bool {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        NSApplication.shared.appearance = appearance
        appearance.map { NSAppearance.current = $0 }

        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("to-do-window-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let store = Store(fileURL: scratch)
        store.add("call the landlord back")

        let view = NSHostingView(rootView: PanelView(store: store))
        view.appearance = appearance
        view.frame = NSRect(x: 0, y: 0, width: Tk.panelWidth, height: 400)
        view.layoutSubtreeIfNeeded()
        let size = NSSize(width: Tk.panelWidth, height: max(view.fittingSize.height, 200))
        view.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = view
        window.orderFront(nil)
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()

        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        try? png.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write(Data("window-rendered \(rep.pixelsWide)x\(rep.pixelsHigh) to \(path)\n".utf8))
        return true
    }

    @MainActor
    static func panel(to path: String, dark: Bool = false) -> Bool {
        // The desk is the only thing that flips, but it is what a screenshot of
        // the real app shows, so both grounds need to be renderable.
        // `NSApp` is nil until the application object exists, and render mode
        // exits before one is built — so make it here.
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        NSApplication.shared.appearance = appearance
        appearance.map { NSAppearance.current = $0 }
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("to-do-render-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: scratch) }

        let store = Store(fileURL: scratch)
        store.add("call the landlord back")
        store.add("hand in the moodboard")
        store.add("pick up prints")
        store.toggle(store.lines[2].id)
        store.togglePin(store.lines[0].id)

        let renderer = ImageRenderer(
            content: PanelView(store: store).environment(\.colorScheme, dark ? .dark : .light)
        )
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return false }

        do {
            try png.write(to: URL(fileURLWithPath: path))
            FileHandle.standardError.write(Data(
                "rendered \(rep.pixelsWide)x\(rep.pixelsHigh) to \(path)\n".utf8))
            return true
        } catch {
            return false
        }
    }
}


/// The menu bar trigger on its own, for the states sheet.
struct TriggerPreview: View {
    let open: Bool
    let count: Int
    let paper: Tk.Paper

    var body: some View {
        let width = StatusGlyphView.width(badge: count > 0)
        ZStack(alignment: .topTrailing) {
            glyph
                .frame(width: width, height: Tk.triggerSize.height)
                .background(
                    open ? Tk.penBlue : .clear,
                    in: RoundedRectangle(cornerRadius: Tk.radiusMd, style: .continuous)
                )
            if count > 0 {
                CountBadge(count: count, paper: paper, noun: "left")
                    .padding([.top, .trailing], 2)
            }
        }
        .frame(width: width, height: Tk.triggerSize.height)
        .fixedSize()
    }

    @ViewBuilder
    private var glyph: some View {
        let mark = Icon(paths: Glyph.note, color: open ? Tk.onPen : Tk.chromeInk, side: 17)
        if count > 0 {
            HStack(spacing: 0) { mark; Spacer(minLength: 0) }.padding(.leading, 4)
        } else {
            mark
        }
    }
}

extension Render {
    /// Captures a real `PanelWindow` through AppKit's own drawing, rather than
    /// `ImageRenderer`.
    ///
    /// This matters: on a variable font, an offscreen `ImageRenderer` resolves a
    /// weight that the on-screen text path does not, so a render can show the
    /// bold instance while the window draws the regular one. Anything about
    /// weight has to be measured here, not there.
    @MainActor
    static func live(to path: String, dark: Bool = true) -> Bool {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        NSApplication.shared.appearance = appearance
        appearance.map { NSAppearance.current = $0 }

        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("to-do-live-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let store = Store(fileURL: scratch)
        store.add("call the landlord back")
        store.add("hand in the moodboard")
        store.add("book the 6am train")
        store.togglePin(store.lines[0].id)
        store.togglePin(store.lines[1].id)
        store.toggle(store.lines[2].id)   // one done, so the footer shows its button
        if let i = CommandLine.arguments.firstIndex(of: "--paper"), i + 1 < CommandLine.arguments.count,
           let paper = Tk.Paper(rawValue: "paper-" + CommandLine.arguments[i + 1]) {
            store.paper = paper
        }

        let window = PanelWindow()
        window.appearance = appearance
        // Near the bottom on purpose: the menu has to flip up rather than fall
        // out of the window.
        let menuAt = CommandLine.arguments.contains("--menu")
            ? CGPoint(x: 120, y: 300) : nil
        let view = NSHostingView(rootView: PanelView(store: store, openNoteMenuAt: menuAt))
        view.frame = NSRect(x: 0, y: 0, width: Tk.panelWidth, height: 240)
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        let height = max(view.fittingSize.height, 160)

        // Far off any screen, so nothing flashes while it draws.
        window.setFrame(NSRect(x: -30000, y: -30000, width: Tk.panelWidth, height: height), display: true)
        window.orderFront(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        window.display()

        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        window.orderOut(nil)

        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        try? png.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write(Data("live capture \(rep.pixelsWide)x\(rep.pixelsHigh) -> \(path)\n".utf8))
        return true
    }
}

extension Render {
    /// Opens the paper picker in a real window, clicks the rose swatch with a
    /// synthesised mouse event, and reports whether the note's paper changed.
    /// This is the only honest test of "can I change the paper": it goes through
    /// AppKit's own event routing, so anything sitting on top of the swatches
    /// and eating the click fails it.
    @MainActor
    static func pickerClickTest() -> Bool {
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("to-do-picker-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let store = Store(fileURL: scratch)
        store.add("call the landlord back")
        store.add("book the 6am train")

        let window = PanelWindow()
        let view = NSHostingView(rootView: PanelView(store: store, openPicker: true))
        view.frame = NSRect(x: 0, y: 0, width: Tk.panelWidth, height: 240)
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        let height = max(view.fittingSize.height, 160)
        window.setFrame(NSRect(x: -30000, y: -30000, width: Tk.panelWidth, height: height), display: true)
        window.orderFront(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        window.display()

        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
        view.cacheDisplay(in: view.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / view.bounds.width

        // Find the rose swatch by its colour.
        var xs = 0.0, ys = 0.0, n = 0.0
        for x in 0..<rep.pixelsWide { for y in 0..<rep.pixelsHigh {
            guard let c = rep.colorAt(x: x, y: y) else { continue }
            // paper-rose by day, #fbeaf0
            if abs(c.redComponent - 0.984) < 0.012 && abs(c.greenComponent - 0.918) < 0.012
                && abs(c.blueComponent - 0.941) < 0.012 { xs += Double(x); ys += Double(y); n += 1 }
        } }
        guard n > 20 else {
            FileHandle.standardError.write(Data("picker test: rose swatch not on screen\n".utf8))
            return false
        }
        // Bitmap is top-down; window coordinates are bottom-up.
        let point = NSPoint(x: xs / n / scale, y: view.bounds.height - ys / n / scale)
        let before = store.paper

        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            if let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                                              timestamp: ProcessInfo.processInfo.systemUptime,
                                              windowNumber: window.windowNumber, context: nil,
                                              eventNumber: 0, clickCount: 1, pressure: 1) {
                window.sendEvent(event)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        window.orderOut(nil)

        FileHandle.standardError.write(Data(
            "picker test: clicked rose at (\(Int(point.x)), \(Int(point.y))) — paper \(before.rawValue) -> \(store.paper.rawValue)\n".utf8))
        return store.paper == .rose
    }
}

extension Render {
    /// The whole path a person takes: right-click the paper, choose Pick paper,
    /// click the rose swatch. Each step is a synthesised click routed through
    /// AppKit, and each step reports what it found.
    @MainActor
    static func pickerFlowTest() -> Bool {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("to-do-flow-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let store = Store(fileURL: scratch)
        store.add("call the landlord back")
        store.add("book the 6am train")

        let window = PanelWindow()
        window.appearance = NSAppearance(named: .darkAqua)
        let view = NSHostingView(rootView: PanelView(store: store, openNoteMenuAt: CGPoint(x: 90, y: 120)))
        view.frame = NSRect(x: 0, y: 0, width: Tk.panelWidth, height: 240)
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        let height = max(view.fittingSize.height, 160)
        window.setFrame(NSRect(x: -30000, y: -30000, width: Tk.panelWidth, height: height), display: true)
        window.orderFront(nil)
        window.makeKey()

        func log(_ s: String) { FileHandle.standardError.write(Data("flow: \(s)\n".utf8)) }
        func settle(_ t: Double = 0.4) { RunLoop.current.run(until: Date().addingTimeInterval(t)); window.display() }

        /// Centre of every pixel matching `match`, in window coordinates.
        func find(_ match: (NSColor) -> Bool) -> NSPoint? {
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
            view.cacheDisplay(in: view.bounds, to: rep)
            let scale = CGFloat(rep.pixelsWide) / view.bounds.width
            var xs = 0.0, ys = 0.0, n = 0.0
            for x in 0..<rep.pixelsWide { for y in 0..<rep.pixelsHigh {
                if let c = rep.colorAt(x: x, y: y), match(c) { xs += Double(x); ys += Double(y); n += 1 }
            } }
            guard n > 40 else { return nil }
            return NSPoint(x: xs / n / scale, y: view.bounds.height - ys / n / scale)
        }
        func click(_ p: NSPoint) {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                if let e = NSEvent.mouseEvent(with: type, location: p, modifierFlags: [],
                                              timestamp: ProcessInfo.processInfo.systemUptime,
                                              windowNumber: window.windowNumber, context: nil,
                                              eventNumber: 0, clickCount: 1, pressure: 1) {
                    window.sendEvent(e)
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.08))
            }
        }
        func near(_ c: NSColor, _ r: Double, _ g: Double, _ b: Double) -> Bool {
            abs(c.redComponent - r) < 0.03 && abs(c.greenComponent - g) < 0.03 && abs(c.blueComponent - b) < 0.03
        }

        settle(0.6)
        // 1. The menu — surface-raised at night, #2a2724.
        guard let row = find({ near($0, 0.165, 0.153, 0.141) }) else { log("menu never appeared"); return false }
        log("menu is open; clicking Pick paper at (\(Int(row.x)), \(Int(row.y)))")
        click(row)
        settle()

        // 2. The picker — the rose swatch at night, #f9d0de.
        guard let rose = find({ near($0, 0.957, 0.890, 0.914)   /* paper-rose at night, #f4e3e9 */ }) else {
            log("Pick paper was chosen, but no rose swatch appeared — the picker did not open")
            window.orderOut(nil); return false
        }
        log("picker is open; clicking rose at (\(Int(rose.x)), \(Int(rose.y)))")
        let before = store.paper
        click(rose)
        settle()
        window.orderOut(nil)
        log("paper \(before.rawValue) -> \(store.paper.rawValue)")
        return store.paper == .rose
    }
}

extension Render {
    /// Right-clicks the second item in a real window and measures how far the
    /// menu opens from the pointer. It should open right at it.
    @MainActor
    static func rowMenuTest() -> Bool {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("to-do-rowmenu-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let store = Store(fileURL: scratch)
        for t in ["one", "two", "three", "four"] { store.add(t) }

        let window = PanelWindow()
        window.appearance = NSAppearance(named: .darkAqua)
        let view = NSHostingView(rootView: PanelView(store: store))
        view.frame = NSRect(x: 0, y: 0, width: Tk.panelWidth, height: 240)
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        let height = max(view.fittingSize.height, 160)
        window.setFrame(NSRect(x: -30000, y: -30000, width: Tk.panelWidth, height: height), display: true)
        window.orderFront(nil); window.makeKey()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6)); window.display()

        // Click on the second row's text: rows start ~66pt down, 28pt apart.
        let clickTop = CGFloat(66 + 28 + 14)          // top-down, in points
        let clickX: CGFloat = 150
        let windowPoint = NSPoint(x: clickX, y: view.bounds.height - clickTop)
        // Hand the right-click to whichever row catcher sits under the point —
        // the same view AppKit would pick — so the coordinate conversion is what
        // is under test, not the harness's event routing.
        func catchers(in v: NSView) -> [RightClickCatcher.Catcher] {
            (v as? RightClickCatcher.Catcher).map { [$0] } ?? v.subviews.flatMap(catchers)
        }
        let target = catchers(in: view).first { c in
            let f = c.convert(c.bounds, to: nil)
            return c.window != nil && f.contains(windowPoint) && c.bounds.height < 60
        }
        guard let target,
              let e = NSEvent.mouseEvent(with: .rightMouseDown, location: windowPoint, modifierFlags: [],
                                         timestamp: ProcessInfo.processInfo.systemUptime,
                                         windowNumber: window.windowNumber, context: nil,
                                         eventNumber: 0, clickCount: 1, pressure: 1)
        else {
            FileHandle.standardError.write(Data("row menu test: no row under the point\n".utf8)); return false
        }
        target.rightMouseDown(with: e)
        RunLoop.current.run(until: Date().addingTimeInterval(0.4)); window.display()

        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?
            .write(to: URL(fileURLWithPath: "/tmp/rowmenu-test.png"))
        let scale = CGFloat(rep.pixelsWide) / view.bounds.width
        // Topmost row of the menu's ground, #2a2724, found as a run of pixels.
        var menuTop: CGFloat?
        outer: for y in 0..<rep.pixelsHigh {
            var run = 0
            for x in 0..<rep.pixelsWide {
                if let c = rep.colorAt(x: x, y: y), abs(c.redComponent - 0.165) < 0.02,
                   abs(c.greenComponent - 0.153) < 0.02, abs(c.blueComponent - 0.141) < 0.02 {
                    run += 1; if run > 60 { menuTop = CGFloat(y) / scale; break outer }
                } else { run = 0 }
            }
        }
        window.orderOut(nil)
        guard let top = menuTop else {
            FileHandle.standardError.write(Data("row menu test: no menu opened\n".utf8)); return false
        }
        let gap = top - clickTop
        FileHandle.standardError.write(Data(String(format:
            "row menu test: clicked at %.0fpt, menu opens at %.1fpt — %.1fpt from the pointer\n",
            clickTop, top, gap).utf8))
        return abs(gap) < 4
    }
}

extension Render {
    /// Right-clicks at a point (top-down, in panel points) through AppKit's real
    /// event queue — posted, dequeued with nextEvent so NSApp.currentEvent is set,
    /// then dispatched — and reports what menu opened. Unlike handing the event
    /// to a known view, this exercises the hit test, which is what decides
    /// whether the click reaches a catcher at all.
    @MainActor
    static func rightClickTest(at points: [CGPoint]) -> Bool {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        NSApplication.shared.finishLaunching()
        var ok = true
        for top in points {
            let scratch = FileManager.default.temporaryDirectory
                .appendingPathComponent("to-do-rc-\(UUID().uuidString).json")
            defer { try? FileManager.default.removeItem(at: scratch) }
            let store = Store(fileURL: scratch)
            for t in ["one", "two", "three"] { store.add(t) }

            let window = PanelWindow()
            window.appearance = NSAppearance(named: .darkAqua)
            let view = NSHostingView(rootView: PanelView(store: store))
            view.frame = NSRect(x: 0, y: 0, width: Tk.panelWidth, height: 240)
            window.contentView = view
            view.layoutSubtreeIfNeeded()
            let height = max(view.fittingSize.height, 160)
            window.setFrame(NSRect(x: 200, y: 200, width: Tk.panelWidth, height: height), display: true)
            window.orderFront(nil); window.makeKey()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5)); window.display()

            let wp = NSPoint(x: top.x, y: view.bounds.height - top.y)
            // Posted and dequeued so NSApp.currentEvent is a right-click while
            // AppKit's own hit test runs (the row catchers only answer then);
            // then handed to whatever that hit test picked. Not sent through
            // NSApp: while someone is using another app, a synthetic click's
            // location is rewritten on the way through.
            if let down = NSEvent.mouseEvent(with: .rightMouseDown, location: wp, modifierFlags: [],
                                             timestamp: ProcessInfo.processInfo.systemUptime,
                                             windowNumber: window.windowNumber, context: nil,
                                             eventNumber: 0, clickCount: 1, pressure: 1) {
                NSApp.postEvent(down, atStart: false)
                _ = NSApp.nextEvent(matching: [.rightMouseDown], until: Date().addingTimeInterval(0.3),
                                    inMode: .default, dequeue: true)
                if let hit = window.contentView?.superview?.hitTest(wp) {
                    if hit is CaretTextField || hit is NSTextView && !(hit is ItemTextView) {
                        // The writing line: AppKit's own text menu, which
                        // would block here in its tracking loop.
                        FileHandle.standardError.write(Data(String(format:
                            "right-click at (%.0f, %.0f): the writing line (system text menu)\n", top.x, top.y).utf8))
                        window.orderOut(nil); ok = false; continue
                    }
                    hit.rightMouseDown(with: down)
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4)); window.display()

            var found = "no menu"
            if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                let scale = CGFloat(rep.pixelsWide) / view.bounds.width
                var rows: [Int] = []
                for y in 0..<rep.pixelsHigh {
                    var run = 0, hit = false
                    for x in 0..<rep.pixelsWide {
                        if let c = rep.colorAt(x: x, y: y), abs(c.redComponent - 0.165) < 0.02,
                           abs(c.greenComponent - 0.153) < 0.02, abs(c.blueComponent - 0.141) < 0.02 {
                            run += 1; if run > 60 { hit = true; break }
                        } else { run = 0 }
                    }
                    if hit { rows.append(y) }
                }
                if let a = rows.first, let b = rows.last {
                    let h = CGFloat(b - a) / scale
                    // 1 row (Pick paper) ~ 40pt; 2 rows ~ 72pt.
                    found = String(format: "menu at %.0fpt, %.0fpt tall — %@", CGFloat(a) / scale, h,
                                   h < 56 ? "the paper's menu (Pick paper)" : "an item's menu")
                }
            }
            window.orderOut(nil)
            FileHandle.standardError.write(Data(String(format: "right-click at (%.0f, %.0f): %@\n",
                                                        top.x, top.y, found).utf8))
            if found == "no menu" { ok = false }
        }
        return ok
    }
}

extension Render {
    /// Clicks once into the second item through AppKit's real event queue,
    /// checks the caret landed there, types, presses Return, and checks the
    /// store took the words. Then the same with Escape, which must put the
    /// words back and leave the panel up.
    @MainActor
    static func editTest() -> Bool {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        NSApplication.shared.finishLaunching()
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("to-do-edit-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let store = Store(fileURL: scratch)
        for t in ["one", "two", "three"] { store.add(t) }

        let window = PanelWindow()
        let view = NSHostingView(rootView: PanelView(store: store))
        view.frame = NSRect(x: 0, y: 0, width: Tk.panelWidth, height: 240)
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        let height = max(view.fittingSize.height, 160)
        window.setFrame(NSRect(x: 200, y: 200, width: Tk.panelWidth, height: height), display: true)
        // The real panel is opened active and key; start the test the same way.
        NSApp.setActivationPolicy(.accessory)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        func items(in v: NSView) -> [ItemTextView] {
            (v as? ItemTextView).map { [$0] } ?? v.subviews.flatMap(items)
        }
        func log(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }
        /// Checks the item is what AppKit would hit at the point, then hands
        /// it the click. Dispatched to the view, not through NSApp: a test
        /// window cannot become key while someone is using another app, and an
        /// inactive app swallows the click to activate itself.
        func click(_ item: ItemTextView) -> Bool {
            let f = item.convert(item.bounds, to: nil)
            let wp = NSPoint(x: f.minX + ItemTextView.swipeOverhang + item.inkWidthOfFirst(2), y: f.midY)
            guard let frame = window.contentView?.superview, frame.hitTest(wp) === item else {
                log("edit test: \"\(item.string)\" is not the view under the pointer"); return false
            }
            window.makeFirstResponder(nil)
            func mouse(_ type: NSEvent.EventType) -> NSEvent? {
                NSEvent.mouseEvent(with: type, location: wp, modifierFlags: [],
                                   timestamp: ProcessInfo.processInfo.systemUptime,
                                   windowNumber: window.windowNumber, context: nil,
                                   eventNumber: 0, clickCount: 1, pressure: 1)
            }
            // The up goes in the queue first: the text view tracks the click
            // in its own loop after mouse-down and waits there for it.
            guard let down = mouse(.leftMouseDown), let up = mouse(.leftMouseUp) else { return false }
            NSApp.postEvent(up, atStart: false)
            // What NSWindow.sendEvent does before it passes a click on.
            window.makeFirstResponder(item)
            item.mouseDown(with: down)
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            return true
        }

        guard let two = items(in: view).first(where: { $0.string == "two" }) else {
            log("edit test: no item \"two\""); return false
        }
        let before = two.convert(two.bounds, to: nil)
        guard click(two) else { return false }
        guard window.firstResponder === two else {
            log("edit test: one click did not put the caret in \"two\""); return false
        }
        let after = two.convert(two.bounds, to: nil)
        log(String(format: "edit test: one click -> caret at %d of \"two\"; row moved %.1fpt",
                   two.selectedRange().location, abs(after.minY - before.minY) + abs(after.minX - before.minX)))
        window.display()
        if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?
                .write(to: URL(fileURLWithPath: "/tmp/edit-test.png"))
        }
        two.selectAll(nil)
        two.insertText("buy two lemons", replacementRange: two.selectedRange())
        two.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let kept = store.lines.map(\.text)
        log("edit test: after Return -> \(kept)")
        guard kept == ["one", "buy two lemons", "three"], after == before else { return false }

        guard let one = items(in: view).first(where: { $0.string == "one" }) else { return false }
        guard click(one) else { return false }
        one.selectAll(nil)
        one.insertText("scrap this", replacementRange: one.selectedRange())
        one.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let reverted = store.lines.map(\.text)
        log("edit test: after Escape -> \(reverted), shows \"\(one.string)\", panel visible: \(window.isVisible)")
        window.orderOut(nil)
        return reverted == kept && one.string == "one"
    }
}
