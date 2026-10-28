import SwiftUI

/// Reports the panel's natural height so the window can follow the list.
struct PanelHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// One window, one note. No sidebar, no settings screen.
struct PanelView: View {
    @ObservedObject var store: Store
    var onHeightChange: (CGFloat) -> Void = { _ in }
    /// Render-mode only: opens the paper's menu at this point so the placement
    /// can be checked in a capture.
    var openNoteMenuAt: CGPoint?
    /// Render-mode only: opens the paper picker, for the click test.
    var openPicker = false

    @State private var draft = ""
    @State private var pickingPaper = false
    @State private var menu: MenuTarget?

    /// Which menu is open, and where the pointer was.
    private struct MenuTarget: Equatable {
        enum Kind: Equatable {
            case item(Line.ID)
            case note
        }
        let kind: Kind
        let at: CGPoint

        var itemID: Line.ID? {
            if case let .item(id) = kind { return id }
            return nil
        }
    }
    @State private var writing = false

    /// `flat` whenever the note has focus — and this note has focus from the
    /// moment it appears, because the panel hands the caret to the writing line
    /// before the window becomes key. So it is flat from the first frame; there
    /// is nothing to straighten.
    ///
    /// `tilt-left` is still the resting pose in `NotePanel`, for a note that is
    /// shown without focus — a second note peeking from a stack, say.
    private var tilt: Double { Tk.tiltFlat }

    var body: some View {
        NotePanel(
            title: "To do list",
            paper: store.paper,
            tilt: tilt,
            shortcut: "⌘⇧T",
            onPaperRightClick: { menu = MenuTarget(kind: .note, at: $0) },
            content: {
                if store.lines.isEmpty {
                    EmptyStateView(line: "nothing here yet", hint: "↩ to keep the item")
                } else {
                    ForEach(store.lines) { line in
                        TodoItemRow(
                            line: line,
                            paper: store.paper,
                            isTarget: menu?.itemID == line.id,
                            onToggle: { store.toggle(line.id) },
                            onRightClick: { menu = MenuTarget(kind: .item(line.id), at: $0) },
                            onEdit: { store.rename(line.id, to: $0) }
                        )
                    }
                }
                // Always last, always visible — never make the person click an
                // add button first, and never open a modal to add a line.
                NewItemLine(text: $draft, paper: store.paper, focused: $writing) {
                    store.add(draft)
                    draft = ""
                }
            },
            footer: { footerLeft }
        )
        .overlay(alignment: .bottom) {
            if pickingPaper { picker }
        }
        // A GeometryReader, so the menu is placed against the panel's real
        // height at layout time. A height tracked in @State is still zero on the
        // frame the menu first appears, and every clamp collapses to the top.
        .overlay {
            GeometryReader { geo in rowMenu(in: geo.size.height) }
                // Only live while a menu is open. It covers the whole panel, so
                // otherwise it sat on top of the paper picker and ate every
                // click on a swatch — which is why changing paper did nothing.
                .allowsHitTesting(menu != nil)
        }
        // Escape closes the menu before it closes the panel.
        .onExitCommand { if menu != nil { menu = nil } }
        // ⌘Z restores the last deleted item.
        .background(
            Button("") { store.undoDelete() }
                .keyboardShortcut("z", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        )
        // window 20 = note 12 + the 8px panel margin.
        .clipShape(RoundedRectangle(cornerRadius: Tk.radiusLg, style: .continuous))
        .background(
            GeometryReader { g in
                Color.clear.preference(key: PanelHeightKey.self, value: g.size.height)
            }
        )
        .onPreferenceChange(PanelHeightKey.self) {
            onHeightChange($0)
            if let at = openNoteMenuAt, menu == nil {
                menu = MenuTarget(kind: .note, at: at)
            }
            if openPicker, !pickingPaper { pickingPaper = true }
        }

    }

    @ViewBuilder
    private func rowMenu(in panelHeight: CGFloat) -> some View {
        if let menu {
            let items = menuItems(for: menu)
            if !items.isEmpty {
                // An explicit ZStack, because `.overlay(alignment:)` does not
                // reach a builder that returns more than one view — it centres
                // them, and the offset then lands half a panel to the right.
                ZStack(alignment: .topLeading) {
                    // A click anywhere else closes it.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { self.menu = nil }

                    RowMenu(items: items, label: menuLabel(for: menu)) { self.menu = nil }
                        .offset(x: menuX(menu.at.x), y: menuY(menu.at.y, items: items, in: panelHeight))
                }
            }
        }
    }

    private func menuItems(for menu: MenuTarget) -> [RowMenu.Item] {
        switch menu.kind {
        case let .item(id):
            guard let line = store.lines.first(where: { $0.id == id }) else { return [] }
            return [
                RowMenu.Item(label: line.pinned ? "Unpin item" : "Pin item",
                             onSelect: { store.togglePin(id) }),
                // The destructive row goes last, in chrome-danger. No separator:
                // the card asks for one only when two or more rows precede it.
                RowMenu.Item(label: "Delete item",
                             onSelect: { store.delete(id) },
                             danger: true)
            ]
        case .note:
            var items = [RowMenu.Item(label: "Pick paper", onSelect: { pickingPaper = true })]
            if store.doneCount > 0 {
                items.append(RowMenu.Item(label: "Clear done items",
                                          onSelect: { store.clearDone() },
                                          danger: true))
            }
            return items
        }
    }

    private func menuLabel(for menu: MenuTarget) -> String {
        if let id = menu.itemID, let line = store.lines.first(where: { $0.id == id }) {
            return line.text
        }
        return "note"
    }

    /// Keep the menu inside the panel rather than letting it hang off the edge.
    private func menuX(_ x: CGFloat) -> CGFloat {
        min(max(x, Tk.space2), Tk.panelWidth - RowMenu.width - Tk.space2)
    }

    /// Below the pointer if it fits, above it if it does not, and never outside
    /// the panel — the window ends at the paper's edge, so anything past it is
    /// simply cut off.
    private func menuY(_ y: CGFloat, items: [RowMenu.Item], in panelHeight: CGFloat) -> CGFloat {
        let height = RowMenu.height(for: items)
        guard panelHeight > height + Tk.space2 * 2 else { return Tk.space2 }
        let lowest = panelHeight - height - Tk.space2
        let wanted = y + height > panelHeight - Tk.space2 ? y - height : y
        return min(max(Tk.space2, wanted), lowest)
    }

    @ViewBuilder
    private var footerLeft: some View {
        if store.undoableDelete != nil {
            HStack(spacing: 0) {
                Text("1 deleted · ")
                    .textStyle(.meta)
                    .foregroundStyle(Tk.inkMuted)
                Button("undo") { store.undoDelete() }
                    .buttonStyle(.plain)
                    .textStyle(.meta)
                    // A link on paper, which is pen-blue's job.
                    .foregroundStyle(Tk.penBlue)
            }
        } else if store.doneCount > 0 {
            // Always paired with a word that says what will go, never a bare icon.
            Button("Clear done items") { store.clearDone() }
                .buttonStyle(NoteButtonStyle(variant: .danger))
        } else {
            Text(store.lines.isEmpty ? "no item yet" : "\(store.openCount) left")
                .textStyle(.meta)
                .foregroundStyle(Tk.inkMuted)
        }
    }

    private var picker: some View {
        PaperSwatches(value: Binding(
            get: { store.paper },
            set: { store.paper = $0; pickingPaper = false }
        ))
        .padding(.bottom, Tk.space4)
        .transition(.opacity)
        .onExitCommand { pickingPaper = false }
    }
}

/// The one control that is always on screen: the note glyph in the menu bar.
/// It sits on the desk, so it takes chrome ink, not the ink used on paper.
struct StatusGlyphView: View {
    @ObservedObject var store: Store
    @ObservedObject var state: PanelState

    private var showsBadge: Bool { store.openCount > 0 }

    /// With a count the button widens from 28 to 34 and the glyph shifts left,
    /// so the chip gets its own corner instead of sitting on the note mark.
    static let countedWidth: CGFloat = 34

    /// What the status item has to be sized to. Nothing in this trigger may
    /// extend beyond its own box: the menu bar runs along the top edge of the
    /// screen, and anything above the button is clipped by it.
    static func width(badge: Bool) -> CGFloat {
        badge ? countedWidth : Tk.triggerSize.width
    }

    var body: some View {
        let width = Self.width(badge: showsBadge)

        ZStack(alignment: .topTrailing) {
            glyph
                .frame(width: width, height: Tk.triggerSize.height)
                // How a person knows the panel belongs to this icon and not the one beside it.
                .background(
                    state.isOpen ? Tk.penBlue : .clear,
                    in: RoundedRectangle(cornerRadius: Tk.radiusMd, style: .continuous)
                )

            if showsBadge {
                CountBadge(count: store.openCount, paper: store.paper, noun: "left")
                .padding([.top, .trailing], 2)
            }
        }
        .frame(width: width, height: Tk.triggerSize.height)
        .fixedSize()
    }

    @ViewBuilder
    private var glyph: some View {
        let mark = Icon(paths: Glyph.note, color: state.isOpen ? Tk.onPen : Tk.chromeInk, side: 17)
        if showsBadge {
            HStack(spacing: 0) {
                mark
                Spacer(minLength: 0)
            }
            .padding(.leading, 4)
        } else {
            mark
        }
    }
}

/// Whether the panel is down. The trigger holds nothing itself.
final class PanelState: ObservableObject {
    @Published var isOpen = false
}
