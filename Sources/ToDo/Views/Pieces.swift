import SwiftUI

// MARK: - Checkbox

/// An 18px box with a hand-drawn tick that overshoots its corners, the way a
/// real one does. The overshoot is most of what makes the app feel handwritten,
/// so it is never clipped.
struct NoteCheckbox: View {
    let checked: Bool
    var disabled = false
    let label: String
    var tick: Color = Tk.penBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: Tk.radiusSm, style: .continuous)
                .strokeBorder(disabled ? Tk.inkFaint : Tk.inkMuted, lineWidth: 1.6)
                .frame(width: 18, height: 18)
                .overlay {
                    if checked {
                        Icon(paths: Glyph.check, color: tick, lineWidth: 2.2, side: 26)
                            .offset(x: 1.5, y: -2)
                            .allowsHitTesting(false)
                    }
                }
                // strokeBorder draws only the ring, and SwiftUI hit-tests what is
                // drawn — without this the box is only clickable on its 1.6pt edge.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .noteFocusRing(radius: Tk.radiusSm)
        .accessibilityLabel(label)
        .accessibilityValue(checked ? "done" : "not done")
    }
}

// MARK: - Count badge

/// A scrap of the note, stuck to the menu bar icon with the number of lines
/// left on it. The badge is paper, not a system dot — so a pink note puts a pink
/// chip in the menu bar and you can tell which note is waiting before the panel
/// is even open.
struct CountBadge: View {
    let count: Int
    /// The paper of the note the count belongs to.
    var paper: Tk.Paper = .chalk
    /// A real noun — "4" on its own tells a screen reader nothing.
    let noun: String

    /// 14px square. Kept that size so it sits entirely within the trigger's 22px
    /// box — macOS clips anything drawn above the menu bar, and a chip that
    /// overhangs the top loses its edge to the screen. Not tilted either: at 14px
    /// a rotation pushes a corner out of that box for no gain.
    static let side: CGFloat = 14

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .textStyle(.badge)
            .foregroundStyle(Tk.ink)
            .padding(.horizontal, 3)
            .frame(minWidth: Self.side, minHeight: Self.side)
            .background(paper.color, in: RoundedRectangle(cornerRadius: Tk.radiusSm, style: .continuous))
            .shadow(color: Tk.surfaceNoteEdge, radius: 0.5, x: 0, y: 1)
            .accessibilityLabel("\(count) \(noun)")
    }
}

// MARK: - Button

/// The only place the system face speaks inside the panel.
struct NoteButtonStyle: ButtonStyle {
    enum Variant { case primary, ghost, danger }
    var variant: Variant = .ghost

    func makeBody(configuration: Configuration) -> some View {
        ButtonBody(configuration: configuration, variant: variant)
    }

    private struct ButtonBody: View {
        let configuration: Configuration
        let variant: Variant
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .textStyle(.label)
                .foregroundStyle(foreground)
                .padding(.vertical, Tk.space2)
                .padding(.horizontal, Tk.space3)
                .background(background)
                .overlay(
                    RoundedRectangle(cornerRadius: Tk.radiusMd, style: .continuous)
                        .stroke(border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Tk.radiusMd, style: .continuous))
                // Hover lifts and nothing else; disabled has no shadow at all.
                .modifier(Lift(active: variant == .primary && isEnabled && hovering))
                .contentShape(RoundedRectangle(cornerRadius: Tk.radiusMd, style: .continuous))
                .onHover { hovering = $0 }
                .animation(.easeInOut(duration: Tk.tiltDuration), value: hovering)
        }

        private var foreground: Color {
            guard isEnabled else { return Tk.inkFaint }
            switch variant {
            case .primary: return Tk.onPen
            case .ghost:   return Tk.ink
            case .danger:  return Tk.penRed
            }
        }

        private var border: Color {
            switch variant {
            case .ghost:            return Tk.hairline
            case .primary, .danger: return isEnabled ? .clear : Tk.hairline
            }
        }

        @ViewBuilder
        private var background: some View {
            switch variant {
            case .primary:
                // Ink, not the accent: the accents are light marks and white on
                // them fails contrast.
                isEnabled ? Tk.ink : Color.clear
            case .ghost, .danger:
                // Hover washes; pressed darkens by moving one paper step, not by opacity.
                (isEnabled && (hovering || configuration.isPressed)) ? Tk.paperHover : Color.clear
            }
        }
    }

    /// shadow-lift, applied only while it is wanted — a shadow modifier always
    /// draws something, so it has to be branched rather than zeroed.
    private struct Lift: ViewModifier {
        let active: Bool
        @ViewBuilder
        func body(content: Content) -> some View {
            if active { content.shadowLift() } else { content }
        }
    }
}

// MARK: - Empty state

/// What a note says when there is nothing on it. One line, one hint, nothing else.
struct EmptyStateView: View {
    var line: String = "nothing here yet"
    var hint: String?

    var body: some View {
        VStack(spacing: 0) {
            Icon(paths: Glyph.note, color: Tk.inkMuted, side: 44)
                .padding(.bottom, Tk.space3)
                .accessibilityHidden(true)
            Text(line)
                .textStyle(.body)
                .foregroundStyle(Tk.inkMuted)
            if let hint {
                Text(hint)
                    .textStyle(.shortcut)
                    .foregroundStyle(Tk.inkMuted)
                    .padding(.top, Tk.space3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tk.space6)
        .padding(.horizontal, Tk.space4)
    }
}

// MARK: - Paper picker

/// Six squares of real paper, floating on surface-raised. Paper is decoration
/// the user owns — never set from code to mean urgent, overdue or done.
struct PaperSwatches: View {
    @Binding var value: Tk.Paper
    var papers: [Tk.Paper] = Tk.Paper.allCases

    var body: some View {
        HStack(spacing: Tk.space2) {
            ForEach(Array(papers.enumerated()), id: \.element.id) { index, paper in
                Swatch(paper: paper, index: index, selected: value == paper,
                       ring: value.accent) { value = paper }
            }
        }
        .padding(Tk.space3)
        .background(Tk.surfaceRaised, in: RoundedRectangle(cornerRadius: Tk.radiusNote, style: .continuous))
        .shadowPopover()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("paper")
    }

    private struct Swatch: View {
        let paper: Tk.Paper
        let index: Int
        let selected: Bool
        /// The current paper's accent, as `--tk-accent` gives it in the stylesheet.
        let ring: Color
        let pick: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: pick) {
                RoundedRectangle(cornerRadius: Tk.radiusMd, style: .continuous)
                    .fill(paper.color)
                    .frame(width: 30, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: Tk.radiusMd, style: .continuous)
                            .stroke(Tk.chromeHairline, lineWidth: 1)
                    )
                    // The ring, not the tilt, is what carries the state, since a
                    // tilt is not visible to everyone.
                    .overlay(
                        RoundedRectangle(cornerRadius: Tk.radiusMd, style: .continuous)
                            .stroke(ring, lineWidth: selected ? 2 : 0)
                    )
                    .modifier(Hover(active: hovering))
                    .rotationEffect(.degrees(
                        selected ? Tk.tiltFlat : (index.isMultiple(of: 2) ? Tk.tiltLeft : Tk.tiltRight)
                    ))
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(.easeInOut(duration: Tk.tiltDuration), value: hovering)
            .animation(.easeInOut(duration: Tk.tiltDuration), value: selected)
            .noteFocusRing(radius: Tk.radiusMd)
            .accessibilityLabel(paper.label)
            .accessibilityAddTraits(selected ? [.isSelected] : [])
        }

        private struct Hover: ViewModifier {
            let active: Bool
            @ViewBuilder
            func body(content: Content) -> some View {
                if active { content.shadowLift() } else { content }
            }
        }
    }
}
