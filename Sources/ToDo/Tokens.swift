import SwiftUI
import AppKit

/// Every value here comes from the design system's tokens.json.
///
/// Two grounds, and the one rule that follows:
/// paper is lit in both themes — a sticky note does not turn off at night — so
/// every paper token, every pen, the highlight and `ink` itself hold
/// the same value in Desk and in Desk at night. The *desk* is the part that
/// flips: `surfaceDesk`, `surfaceRaised` and the chrome on them take the
/// `chrome*` inks, which are the only tokens with a light and a dark value.
///
/// Text on paper is `ink` / `inkMuted`. Text on the desk is `chromeInk` /
/// `chromeInkMuted`. Mixing them is what makes a theme look broken.
enum Tk {

    // MARK: Paper — lit in both themes

    enum Paper: String, CaseIterable, Codable, Identifiable {
        case butter = "paper-butter"
        case rose   = "paper-rose"
        case sky    = "paper-sky"
        case mint   = "paper-mint"
        case lilac  = "paper-lilac"
        case chalk  = "paper-chalk"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .butter: "butter"
            case .rose:   "rose"
            case .sky:    "sky"
            case .mint:   "mint"
            case .lilac:  "lilac"
            case .chalk:  "chalk"
            }
        }

        var color: Color {
            switch self {
            case .butter: dyn("#fdf6d9", "#f6efd2")
            case .rose:   dyn("#fbeaf0", "#f4e3e9")
            case .sky:    dyn("#eaf1f9", "#e3eaf2")
            case .mint:   dyn("#e9f4ec", "#e2ede5")
            case .lilac:  dyn("#f0ebf7", "#e9e4f0")
            case .chalk:  dyn("#fcfbf8", "#f5f4f1")
            }
        }

        /// The paper's own mark: the tick, the caret, the focus ring. A light
        /// shade drawn from the paper's hue. It clears the 3:1 floor for a
        /// graphic but not 4.5:1 for text — never set type in it, and never put
        /// white on it.
        var accent: Color {
            switch self {
            case .butter: fixed("#93792f")   // light ochre
            case .rose:   fixed("#b05a7d")   // muted raspberry
            case .sky:    fixed("#4b7ba8")   // slate blue
            case .mint:   fixed("#4f8464")   // moss green
            case .lilac:  fixed("#7566a8")   // muted violet
            case .chalk:  fixed("#5470a3")   // plain pen blue, a step lighter than pen-blue
            }
        }

        /// The highlighter swipe behind a pinned item. Light and vivid, like
        /// real highlighter ink: about as light as its paper, separated by hue
        /// (CIELAB delta-E 15 or more), not by darkness. Amber on butter, since
        /// yellow on yellow leaves no mark.
        var highlight: Color {
            switch self {
            case .butter: fixed("#f7cf5e")   // warm amber
            case .rose:   fixed("#ffa8c6")   // pink
            case .sky:    fixed("#8ccdf0")   // blue
            case .mint:   fixed("#9ce29f")   // green
            case .lilac:  fixed("#c9aeff")   // violet
            case .chalk:  Tk.markerHighlight
            }
        }

        var countInk: Color { self == .mint ? Tk.ink : Tk.penGreen }
    }

    // MARK: The desk — the part that flips

    static let surfaceDesk      = dyn("#eceae5", "#211f1c")
    static let surfaceRaised    = dyn("#fffefb", "#2a2724")
    static let chromeInk        = dyn("#2e2a24", "#f0ece3")
    static let chromeInkMuted   = dyn("#665d4e", "#a9a294")
    static let chromeHairline   = dyn("#2e2a24", "#f0ece3", alpha: 0.149)
    /// The destructive row in a menu, on surface-raised. `penRed` is mixed for
    /// paper and only makes 2.3:1 on the dark menu — this is its chrome twin.
    static let chromeDanger     = dyn("#a8352c", "#f08b7e")
    /// The tape strip pinning a note to the desk. Decorative only.
    static let tape             = dyn("#e7e0cf", "#fffdf0", alphaLight: 0.851, alphaDark: 0.702)

    // MARK: Ink on paper — the same in both themes

    static let ink       = fixed("#2e2a24")
    static let inkMuted  = fixed("#665d4e")
    /// Disabled outlines and non-essential marks on paper. Dark enough to clear
    /// 3:1 on all six papers — the old #b0a898 vanished on rose, sky and lilac.
    /// Never text, and never an icon a person has to find.
    static let inkFaint  = fixed("#7f7560")

    // MARK: Pens — always on paper, so never themed

    static let penBlue         = fixed("#46639c")
    static let penRed          = fixed("#a8352c")
    static let penGreen        = fixed("#30682b")
    static let markerHighlight = fixed("#ffdf66")
    static let onHighlight     = fixed("#2e2a24")
    static let onPen           = fixed("#fffefb")

    // MARK: Lines and washes on paper

    /// The divider between a note and its footer.
    static let hairline = fixed("#2e2a24", alpha: 0.149)
    /// Hover and pressed wash on a row or a ghost button sitting on paper.
    static let paperHover = fixed("#2e2a24", alpha: 0.051)
    /// The curl band along the bottom of a note — ink at low alpha, so it
    /// darkens whichever paper is underneath rather than naming a colour.
    static let surfaceNoteEdge = fixed("#2e2a24", alpha: 0.078)

    /// The fallback ring, off paper. On a note the ring follows that note's
    /// accent instead — see `\.noteAccent`. On the desk, use `chromeInk`.
    static let focusRing = penBlue

    // MARK: Spacing — a 4px grid, plus the one ruled step

    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 24
    static let space6: CGFloat = 32
    /// The writing rhythm. Every list row is one step tall and item leading
    /// matches it, so a blank note still reads as evenly spaced handwriting.
    static let spaceLine: CGFloat = 28

    // MARK: Radius — nested, and the nesting is the point
    //
    // window 20 = note 12 + the 8px panel margin, so the note's corner runs
    // parallel to the window's instead of cutting across it. Change the panel
    // margin and radiusLg has to move by the same amount.

    static let radiusSm: CGFloat   = 4    // checkboxes, tape, key caps
    static let radiusMd: CGFloat   = 8    // buttons, paper swatches, menu rows, the row hover wash
    static let radiusNote: CGFloat = 12   // the sticky note, and the paper picker
    static let radiusLg: CGFloat   = 20   // the popover window under the menu bar

    // MARK: Tilt

    static let tiltLeft:  Double = -1.4
    static let tiltRight: Double = 1.2
    static let tiltFlat:  Double = 0
    /// "Animate that straightening in 120ms and nothing else."
    static let tiltDuration: Double = 0.12

    // MARK: Panel

    static let panelWidth: CGFloat = 320
    static let triggerSize = CGSize(width: 28, height: 22)
}

// MARK: - Shadows

extension View {
    /// shadow-note — a note resting on surface-desk.
    func shadowNote() -> some View {
        shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 4)
    }

    /// shadow-lift — a note or swatch being dragged or hovered.
    func shadowLift() -> some View {
        shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 7)
    }

    /// shadow-popover — the whole panel hanging off the menu bar, and the paper picker.
    func shadowPopover() -> some View {
        shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 10)
            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
    }

    /// "Every interactive element takes a solid 2px focus-ring at 2px offset.
    /// Never dashed, never a shadow-only focus, never removed on mouse input —
    /// this app is used from a keyboard shortcut, so focus is the main way in."
    func noteFocusRing(radius: CGFloat = Tk.radiusSm) -> some View {
        modifier(NoteFocusRing(radius: radius))
    }
}

/// Makes a control focusable and draws the system's ring in our own ink.
/// `focusable()` is explicit so the ring shows without Full Keyboard Access,
/// and the built-in effect is turned off so there is only ever one ring.
struct NoteFocusRing: ViewModifier {
    let radius: CGFloat
    @FocusState private var focused: Bool
    @Environment(\.noteAccent) private var accent

    func body(content: Content) -> some View {
        content
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .overlay(
                RoundedRectangle(cornerRadius: radius + 2, style: .continuous)
                    .inset(by: -3)
                    .stroke(accent, lineWidth: focused ? 2 : 0)
            )
    }
}

// MARK: - Colour helpers

/// A token that holds the same value in both themes — every ink and pen on paper.
func fixed(_ hex: String, alpha: Double = 1) -> Color {
    Color(nsColor: NSColor(hex: hex).withAlphaComponent(alpha))
}

/// A token that flips with the theme — only the desk and its chrome.
func dyn(_ light: String, _ dark: String, alpha: Double = 1) -> Color {
    dyn(light, dark, alphaLight: alpha, alphaDark: alpha)
}

func dyn(_ light: String, _ dark: String, alphaLight: Double, alphaDark: Double) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(hex: isDark ? dark : light)
            .withAlphaComponent(isDark ? alphaDark : alphaLight)
    })
}

extension NSColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v & 0xFF0000) >> 16) / 255
        let g = Double((v & 0x00FF00) >> 8) / 255
        let b = Double(v & 0x0000FF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}


// MARK: - The note's accent, handed down

/// `NotePanel` sets this from the paper, the way the stylesheet sets
/// `--tk-accent`; anything drawn on the note reads it. Off paper it falls back
/// to pen-blue.
private struct NoteAccentKey: EnvironmentKey {
    static let defaultValue: Color = Tk.penBlue
}

extension EnvironmentValues {
    var noteAccent: Color {
        get { self[NoteAccentKey.self] }
        set { self[NoteAccentKey.self] = newValue }
    }
}
