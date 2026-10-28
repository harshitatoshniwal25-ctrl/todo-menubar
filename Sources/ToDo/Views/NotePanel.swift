import SwiftUI

/// The window itself: the panel that hangs from the menu bar, with one note on it.
/// The component owns only the paper, the tape and the curl — everything inside
/// comes from the caller.
///
/// The paper is blank, with no printed rules. The rhythm is held by the rows
/// themselves, so any row put in has to be a multiple of `space-line` tall or
/// the handwriting starts to drift.
struct NotePanel<Content: View, Footer: View>: View {
    let title: String
    let paper: Tk.Paper
    /// `flat` whenever the note has focus; the straightening animates in 120ms.
    let tilt: Double
    var tape: Bool = true
    let shortcut: String
    /// Right-click on the paper itself, anywhere an item is not.
    var onPaperRightClick: ((CGPoint) -> Void)? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        note
            .padding(Tk.space2)
            .frame(width: Tk.panelWidth)
            .background(Tk.surfaceDesk)
    }

    private var note: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The 34px line is sized around the marker face's descender. Never
            // constrain this heading's height or clip it, or every y and g in a
            // weekday loses its tail.
            NoteHeading(text: title, style: .title, color: Tk.ink)
                .fixedSize()
                // Static text. Left hit-testable, the label swallows a right-click
                // on the heading and the paper's menu never opens.
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, alignment: .leading)
                // space-1, as `.tk-note__title`'s margin specifies.
                .padding(.bottom, Tk.space1)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 0) { content() }

            footerRow
        }
        .padding(.horizontal, Tk.space3)
        // The paper's accent reaches every tick, caret and focus ring on it.
        .environment(\.noteAccent, paper.accent)
        // space-5, not the stylesheet's space-4, to sit the heading lower on
        // the paper. The tape crosses the note's top edge, and 16pt put the
        // heading close under it.
        .padding(.top, Tk.space5)
        // Above the paper, below the content: rows keep their own catchers on
        // top, and every patch of bare paper still answers a right-click. Put
        // behind `paper.color` instead, the paper wins the hit test and the
        // catcher never hears a thing.
        .background {
            if let onPaperRightClick { RightClickCatcher(onRightClick: onPaperRightClick) }
        }
        .background(paper.color)
        // No curl band. The stylesheet gives the note a 6pt `surface-note-edge`
        // strip along its bottom — `.tk-note__curl` — but on a panel this small
        // it reads as a border under the footer rather than as paper lifting.
        // The note's edge is the shadow alone.
        .clipShape(RoundedRectangle(cornerRadius: Tk.radiusNote, style: .continuous))
        .overlay(alignment: .top) {
            if tape {
                RoundedRectangle(cornerRadius: Tk.radiusSm, style: .continuous)
                    .fill(Tk.tape)
                    .frame(width: 74, height: 20)
                    .shadow(color: Tk.surfaceNoteEdge, radius: 1, x: 0, y: 1)
                    .rotationEffect(.degrees(Tk.tiltRight))
                    .offset(y: -9)
                    .accessibilityHidden(true)
            }
        }
        .shadowNote()
        .rotationEffect(.degrees(tilt))
        .animation(.easeInOut(duration: Tk.tiltDuration), value: tilt)
    }

    /// The count on the left and one key hint on the right. Give it nothing else —
    /// a third element and the note starts looking like an app.
    private var footerRow: some View {
        HStack(spacing: Tk.space2) {
            footer()
            Spacer(minLength: Tk.space2)
            Text(shortcut)
                .textStyle(.shortcut)
                .foregroundStyle(Tk.inkMuted)
        }
        .padding(.top, Tk.space2)
        .padding(.bottom, Tk.space3)
        .overlay(alignment: .top) {
            Rectangle().fill(Tk.hairline).frame(height: 1)
        }
        .padding(.top, Tk.space4)
    }
}
