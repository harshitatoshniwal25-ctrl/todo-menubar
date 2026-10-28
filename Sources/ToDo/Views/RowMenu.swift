import SwiftUI
import AppKit

/// The menu an item opens when you right-click it.
///
/// It floats on chrome, so its colours are chrome colours: `surfaceRaised`
/// ground, `chromeInk` text, `chromeHairline` for the hover wash and the
/// separator. The destructive row takes `chromeDanger`, never `penRed` —
/// `penRed` is mixed for paper and only reaches 2.3:1 on the dark menu.
///
/// Four rows at most. Past that it stops being a shortcut and becomes a screen,
/// and this panel does not have screens.
struct RowMenu: View {
    struct Item: Identifiable {
        let id = UUID()
        var label: String = ""
        var onSelect: (() -> Void)?
        /// Renders in chrome-danger and goes last.
        var danger = false
        /// A rule instead of a row; label and onSelect are ignored.
        var separator = false

        static func rule() -> Item { Item(separator: true) }
    }

    let items: [Item]
    /// Accessible name — the item's own text.
    let label: String
    let onClose: () -> Void

    static let width: CGFloat = 168
    /// A row is `label`'s 16pt line plus space-2 top and bottom; a separator is a
    /// hairline plus space-1 either side; the menu adds space-1 of its own.
    static let rowHeight: CGFloat = 16 + Tk.space2 * 2
    static let separatorHeight: CGFloat = 1 + Tk.space1 * 2

    static func height(for items: [Item]) -> CGFloat {
        items.prefix(4).reduce(Tk.space1 * 2) { total, item in
            total + (item.separator ? separatorHeight : rowHeight)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items.prefix(4)) { item in
                if item.separator {
                    Rectangle()
                        .fill(Tk.chromeHairline)
                        .frame(height: 1)
                        .padding(.vertical, Tk.space1)
                        .padding(.horizontal, Tk.space2)
                } else {
                    Row(item: item, onClose: onClose)
                }
            }
        }
        .padding(Tk.space1)
        .frame(width: Self.width, alignment: .leading)
        .background(Tk.surfaceRaised, in: RoundedRectangle(cornerRadius: Tk.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tk.radiusMd, style: .continuous)
                .stroke(Tk.chromeHairline, lineWidth: 1)
        )
        .shadowPopover()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private struct Row: View {
        let item: Item
        let onClose: () -> Void
        @State private var hovering = false

        var body: some View {
            Button {
                item.onSelect?()
                onClose()
            } label: {
                Text(item.label)
                    .textStyle(.label)
                    // This is chrome, so the system face is correct here.
                    .foregroundStyle(item.danger ? Tk.chromeDanger : Tk.chromeInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Tk.space2)
                    .padding(.horizontal, Tk.space3)
                    .background(
                        hovering ? Tk.chromeHairline : .clear,
                        in: RoundedRectangle(cornerRadius: Tk.radiusSm, style: .continuous)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }
}

/// Reports a right-click, in the panel's own top-left coordinates.
///
/// SwiftUI has no right-click gesture other than `.contextMenu`, which draws a
/// system menu we cannot colour — and the system menu is exactly what RowMenu
/// replaces.
struct RightClickCatcher: NSViewRepresentable {
    let onRightClick: (CGPoint) -> Void

    func makeNSView(context: Context) -> NSView { Catcher(onRightClick) }

    func updateNSView(_ view: NSView, context: Context) {
        (view as? Catcher)?.onRightClick = onRightClick
    }

    final class Catcher: NSView {
        var onRightClick: (CGPoint) -> Void

        init(_ onRightClick: @escaping (CGPoint) -> Void) {
            self.onRightClick = onRightClick
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("not from a nib") }

        /// Invisible to a left click, so the checkbox underneath still works;
        /// only a right click (or a ctrl-click) reaches this view.
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent else { return nil }
            switch event.type {
            case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
                return super.hitTest(point)
            case .leftMouseDown where event.modifierFlags.contains(.control):
                return super.hitTest(point)
            default:
                return nil
            }
        }

        override func rightMouseDown(with event: NSEvent) {
            guard let root = window?.contentView else { return }
            let inRoot = root.convert(event.locationInWindow, from: nil)
            // SwiftUI measures down from the top. An NSHostingView is already
            // flipped, so convert() hands back top-down y and must not be flipped
            // again — doing so opened the menu mirrored about the panel's middle,
            // far from the item it belonged to.
            let y = root.isFlipped ? inRoot.y : root.bounds.height - inRoot.y
            onRightClick(CGPoint(x: inRoot.x, y: y))
        }
    }
}
