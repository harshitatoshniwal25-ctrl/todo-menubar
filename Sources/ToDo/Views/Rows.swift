import SwiftUI
import AppKit

/// One written line of the list, with its checkbox. The row is one `space-line`
/// tall and the text sits at `item`, whose 28px leading matches it. On blank
/// paper those two are the only thing holding the list to an even rhythm.
struct TodoItemRow: View {
    @State private var hovering = false
    let line: Line
    let paper: Tk.Paper
    /// True while this row's menu is open, so it is obvious which item is about
    /// to change.
    let isTarget: Bool
    let onToggle: () -> Void
    let onRightClick: (CGPoint) -> Void
    /// Called with the new words when an edit ends.
    let onEdit: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Tk.space2) {
            NoteCheckbox(checked: line.done, label: line.text, tick: paper.accent, action: onToggle)
                .padding(.top, TextStyle.item.markTop(side: 18))

            // Always editable, like a line in Notes: click anywhere in the
            // words and the caret lands there. Nothing swaps in or out, so
            // nothing moves.
            ItemText(
                text: line.text,
                ink: line.done ? Tk.inkMuted : (line.pinned ? Tk.onHighlight : Tk.ink),
                highlight: line.pinned && !line.done ? paper.highlight : nil,
                struck: line.done,
                caret: paper.accent,
                onCommit: onEdit,
                onRightClick: onRightClick
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            // The view reaches 3pt past the words on each side, so the
            // highlighter's overhang is drawn instead of clipped.
            .padding(.horizontal, -ItemTextView.swipeOverhang)
        }
        .padding(.horizontal, Tk.space1)
        .frame(minHeight: Tk.spaceLine, alignment: .top)
        // Hover raises with a wash and nothing more; the open menu's row keeps it.
        .background(
            hovering || isTarget ? Tk.paperHover : .clear,
            in: RoundedRectangle(cornerRadius: Tk.radiusMd, style: .continuous)
        )
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        .overlay(RightClickCatcher(onRightClick: onRightClick))
    }
}

// MARK: - An item's words

/// The words of one item, set in an AppKit text view so they can be edited in
/// place at any moment — the way a line in Notes is — rather than swapping a
/// label for a field on double-click, which made the row jump.
///
/// The text view draws everything the old `Text` did: `item` on a 28pt line,
/// the pinned highlighter swipe, and the hand-drawn strike on a done item.
/// Return or clicking away keeps the edit; Escape puts the words back.
struct ItemText: NSViewRepresentable {
    let text: String
    let ink: Color
    let highlight: Color?
    let struck: Bool
    let caret: Color
    let onCommit: (String) -> Void
    /// The row's menu. The text view sits above the row's right-click catcher,
    /// so it has to hand the click on itself.
    let onRightClick: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> ItemTextView {
        let view = ItemTextView()
        view.delegate = context.coordinator
        view.drawsBackground = false
        view.isRichText = false
        view.allowsUndo = true
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.textContainerInset = NSSize(width: ItemTextView.swipeOverhang, height: 0)
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.focusRingType = .none
        view.setAccessibilityLabel("item")
        return view
    }

    func updateNSView(_ view: ItemTextView, context: Context) {
        context.coordinator.parent = self
        view.onRightClick = onRightClick
        view.insertionPointColor = NSColor(caret)
        view.selectedTextAttributes = [.backgroundColor: NSColor(caret).withAlphaComponent(0.22)]
        let attributes = ItemTextView.attributes(ink: ink, highlight: highlight, struck: struck)
        view.typingAttributes = attributes
        // Never rewrite the words under someone's caret.
        guard !view.isEditing else { return }
        let next = NSAttributedString(string: text, attributes: attributes)
        if view.attributedString() != next {
            view.textStorage?.setAttributedString(next)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ItemTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 260
        return CGSize(width: width, height: nsView.height(forWidth: width))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ItemText
        /// The words when editing began, for Escape.
        private var original = ""
        init(_ parent: ItemText) { self.parent = parent }

        func textDidBeginEditing(_ note: Notification) {
            original = parent.text
        }

        func textDidChange(_ note: Notification) {
            // Wrapping may have changed; let SwiftUI ask for the height again.
            (note.object as? NSView)?.invalidateIntrinsicContentSize()
        }

        func textDidEndEditing(_ note: Notification) {
            guard let view = note.object as? ItemTextView else { return }
            let words = view.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if words.isEmpty {
                // An emptied item keeps its old words; delete is on the menu.
                view.string = original
                view.typingAttributes = ItemTextView.attributes(
                    ink: parent.ink, highlight: parent.highlight, struck: parent.struck)
                view.textStorage?.setAttributes(view.typingAttributes,
                                                range: NSRange(location: 0, length: view.string.utf16.count))
            } else {
                parent.onCommit(words)
            }
        }

        func textView(_ view: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                view.window?.makeFirstResponder(nil)
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                view.string = original
                view.window?.makeFirstResponder(nil)
                return true
            default:
                return false
            }
        }
    }
}

/// The text view behind an item. Its layout manager draws the highlighter
/// swipe and the strike by hand, so both follow the words as they are typed
/// and as they wrap.
final class ItemTextView: NSTextView {
    private let drawing = ItemLayoutManager()

    init() {
        let storage = NSTextStorage()
        let container = NSTextContainer(size: NSSize(width: 260, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(drawing)
        drawing.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override init(frame: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
    }

    var isEditing: Bool { window?.firstResponder === self }

    var onRightClick: (CGPoint) -> Void = { _ in }

    /// The panel is a popover: the first click into it should land the caret,
    /// not just wake the window.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// No system text menu: a right-click on an item opens the item's menu,
    /// exactly as it does anywhere else on the row.
    override func menu(for event: NSEvent) -> NSMenu? { nil }

    override func rightMouseDown(with event: NSEvent) {
        guard let root = window?.contentView else { return }
        let inRoot = root.convert(event.locationInWindow, from: nil)
        // Same conversion as RightClickCatcher: the hosting view is flipped.
        onRightClick(CGPoint(x: inRoot.x, y: root.isFlipped ? inRoot.y : root.bounds.height - inRoot.y))
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { rightMouseDown(with: event); return }
        super.mouseDown(with: event)
    }

    /// Test hook: how far in the first `n` characters reach.
    func inkWidthOfFirst(_ n: Int) -> CGFloat {
        TextStyle.item.inkWidth(of: String(string.prefix(n)))
    }

    /// How far the highlighter swipe runs past the words on either side.
    static let swipeOverhang: CGFloat = 3

    /// `item` on a `space-line` line, with the glyphs centred in it the way
    /// CSS line-height centres them.
    static func attributes(ink: Color, highlight: Color?, struck: Bool) -> [NSAttributedString.Key: Any] {
        let style = TextStyle.item
        let font = style.face.nsFont(size: style.size, weight: style.nsWeight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = style.leading
        paragraph.maximumLineHeight = style.leading
        paragraph.lineBreakMode = .byWordWrapping
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(ink),
            .paragraphStyle: paragraph,
            .baselineOffset: ItemLayoutManager.baselineLift(for: font, leading: style.leading)
        ]
        if let highlight { attributes[.itemSwipe] = NSColor(highlight) }
        if struck { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        return attributes
    }

    /// The highlighter swipe: the glyphs' own height, not the 28pt line, with
    /// `swipeOverhang` of marker either side — the swipe `Text` used to draw.
    /// Drawn here rather than as a background attribute, which TextKit clips
    /// to the text column and so loses the overhang.
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let storage = textStorage, let manager = layoutManager, let container = textContainer else { return }
        let origin = textContainerOrigin
        let trim = TextStyle.item.halfLeading
        let o = Self.swipeOverhang
        storage.enumerateAttribute(.itemSwipe, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard let color = value as? NSColor else { return }
            let glyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            color.setFill()
            manager.enumerateEnclosingRects(forGlyphRange: glyphs,
                                            withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                            in: container) { r, _ in
                NSRect(x: origin.x + r.minX - o, y: origin.y + r.minY + trim,
                       width: r.width + o * 2, height: max(0, r.height - trim * 2)).fill()
            }
        }
    }

    func height(forWidth width: CGFloat) -> CGFloat {
        guard let container = textContainer, let manager = layoutManager else { return TextStyle.item.leading }
        container.containerSize = NSSize(width: max(1, width - Self.swipeOverhang * 2),
                                         height: .greatestFiniteMagnitude)
        manager.ensureLayout(for: container)
        let used = manager.usedRect(for: container).height
        return max(TextStyle.item.leading, used.rounded(.up))
    }
}

/// Draws the strike on a done item in place of AppKit's straight rule.
final class ItemLayoutManager: NSLayoutManager {
    /// How far to lift the glyphs so they sit centred in a line that is
    /// taller than the font — TextKit puts the extra room above them.
    static func baselineLift(for font: NSFont, leading: CGFloat) -> CGFloat {
        let natural = font.ascender - font.descender + font.leading
        return max(0, (leading - natural) / 2)
    }

    /// The strike is a hand-drawn stroke across the words, never
    /// text-decoration — so AppKit's straight rule is replaced with the curve.
    override func drawStrikethrough(forGlyphRange glyphRange: NSRange, strikethroughType: NSUnderlineStyle,
                                    baselineOffset: CGFloat, lineFragmentRect lineRect: NSRect,
                                    lineFragmentGlyphRange: NSRange, containerOrigin origin: NSPoint) {
        guard let container = textContainer(forGlyphAt: glyphRange.location, effectiveRange: nil) else { return }
        let box = boundingRect(forGlyphRange: glyphRange, in: container)
        let x0 = origin.x + box.minX - 2, x1 = origin.x + box.maxX + 2
        let y = origin.y + lineRect.minY + lineRect.height * 0.52
        let w = x1 - x0
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x0, y: y + 1.6))
        path.curve(to: NSPoint(x: x1, y: y - 1.1),
                   controlPoint1: NSPoint(x: x0 + w * 0.34, y: y - 2.4),
                   controlPoint2: NSPoint(x: x0 + w * 0.67, y: y + 2.1))
        path.lineWidth = 1.6
        path.lineCapStyle = .round
        NSColor(Tk.inkMuted).setStroke()
        path.stroke()
    }
}

/// The always-present last row of a note, where the next line gets written.
/// It looks like a line, not a field: no border, no filled background,
/// transparent ground so the paper shows through.
struct NewItemLine: View {
    @Binding var text: String
    let paper: Tk.Paper
    @Binding var focused: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Tk.space2) {
            // The only chrome is the plus, which turns to the pen while focused.
            Icon(paths: Glyph.plus,
                 color: focused ? paper.accent : Tk.inkMuted,
                 side: 18)
                .padding(.top, TextStyle.item.markTop(side: 18))
                .animation(.easeInOut(duration: Tk.tiltDuration), value: focused)

            NoteTextField(
                text: $text,
                isFocused: $focused,
                placeholder: "write an item",
                label: "write an item",
                caret: paper.accent,
                onSubmit: onSubmit
            )
            // The whole row: NSTextField centres its string in whatever height it
            // is given, so a space-line-tall field lands close to where the
            // SwiftUI Text in a written line does.
            .frame(height: Tk.spaceLine)
            // Close, but not equal — AppKit still sets the baseline 2.93pt higher
            // than SwiftUI does at the same font and metrics. Measured from a live
            // capture; it is not derivable from the font, since the layout
            // manager's line height (21.00) is shorter than the font's natural
            // line (21.44), so it is not that. Without it the placeholder floats
            // above the plus beside it and the row reads as misaligned.
            .padding(.top, 2.93)
        }
        .padding(.horizontal, Tk.space1)
        .frame(minHeight: Tk.spaceLine, alignment: .top)
    }
}

// MARK: - The field itself

/// An AppKit field rather than a SwiftUI TextField.
///
/// SwiftUI's `foregroundStyle` does not reach the editable text of a macOS text
/// field, and neither does a `prompt`'s colour: both fall back to the system
/// label colours, which are near-white in dark mode. On paper — which stays lit
/// at night — that meant the handwriting and the `write a line` placeholder
/// came out white on yellow. Setting `textColor`, the placeholder attributes
/// and the caret directly is the only way to hold them to `ink`, `ink-muted`
/// and `pen-blue`.
struct NoteTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let label: String
    let caret: Color
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> CaretTextField {
        let field = CaretTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.setAccessibilityLabel(label)
        return field
    }

    func updateNSView(_ field: CaretTextField, context: Context) {
        context.coordinator.parent = self

        let font = Face.hand.nsFont(size: TextStyle.item.size, weight: .regular)
        field.font = font
        field.textColor = NSColor(Tk.ink)
        field.caretColor = NSColor(caret)
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.font: font, .foregroundColor: NSColor(Tk.inkMuted)]
        )
        if field.stringValue != text { field.stringValue = text }
        if let editor = field.currentEditor() as? NSTextView {
            editor.insertionPointColor = NSColor(caret)
            CaretTextField.stripInset(editor)
        }
        if isFocused, field.currentEditor() == nil {
            DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NoteTextField
        init(_ parent: NoteTextField) { self.parent = parent }

        func controlTextDidChange(_ note: Notification) {
            guard let field = note.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidBeginEditing(_ note: Notification) {
            guard !parent.isFocused else { return }
            DispatchQueue.main.async { self.parent.isFocused = true }
        }

        func controlTextDidEndEditing(_ note: Notification) {
            guard parent.isFocused else { return }
            DispatchQueue.main.async { self.parent.isFocused = false }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                // The field would otherwise eat Escape, and the panel would
                // stay down when the whole point is that it disappears.
                control.window?.cancelOperation(nil)
                return true
            default:
                return false
            }
        }
    }
}

/// On a note, the caret is the only cursor a person watches, so it is pen-blue
/// (or ink, on the two papers where a pen mark would read as a smudge).
final class CaretTextField: NSTextField {
    var caretColor: NSColor = .textColor

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted, let editor = currentEditor() as? NSTextView {
            editor.insertionPointColor = caretColor
            Self.stripInset(editor)
        }
        return accepted
    }

    /// The shared field editor indents text by `lineFragmentPadding` (2pt) and
    /// the cell's placeholder does not, so the moment you started typing the
    /// line jumped 2pt right — away from the plus, and out of line with every
    /// row above it. The note has no field chrome to inset from.
    static func stripInset(_ editor: NSTextView) {
        editor.textContainer?.lineFragmentPadding = 0
        editor.textContainerInset = .zero
    }
}


/// The date at the head of a note, drawn by AppKit rather than SwiftUI.
///
/// A live window rasterises a SwiftUI `Text` into a layer sized to the string's
/// **advance** width, and clips whatever inks past it. Caveat overhangs its
/// advance by about 1.5pt on "Today" — which is the tail of the y — so the tail
/// was being cut on screen while every offscreen render showed it whole.
/// Widening the SwiftUI frame does not help: the frame is not what sizes the
/// layer. An `NSTextField` given bounds wide enough for the ink is.
struct NoteHeading: NSViewRepresentable {
    let text: String
    let style: TextStyle
    let color: Color

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.truncatesLastVisibleLine = false
        field.lineBreakMode = .byClipping
        field.setContentCompressionResistancePriority(.required, for: .horizontal)
        field.setContentCompressionResistancePriority(.required, for: .vertical)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        field.font = style.face.nsFont(size: style.size, weight: style.nsWeight)
        field.textColor = NSColor(color)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextField, context: Context) -> CGSize? {
        // The box is the design's line box, not the field's intrinsic height.
        // NSTextField centres the text in whatever height it is given, so a
        // `leading`-tall box puts half the leading above and half below — which
        // is what CSS line-height does. Using the intrinsic height instead left
        // ~11pt of slack under the text and pushed the list down.
        CGSize(width: style.inkWidth(of: text), height: style.leading)
    }
}

extension NSAttributedString.Key {
    /// A highlighter swipe behind these words, drawn by `ItemTextView`.
    static let itemSwipe = NSAttributedString.Key("ToDoItemSwipe")
}
