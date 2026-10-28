import SwiftUI
import AppKit
import CoreText

/// Three faces, each with one job. The system face is the only thing in to do
/// allowed to look like software, so it stays at the edges.
enum Face {
    case script   // Caveat — the app name and every date heading
    case hand     // Shantell Sans — the list itself
    case ui       // the system face — buttons, menu rows, timestamps, key hints

    /// The fallbacks named in tokens.json, so a note never renders in the system serif.
    var candidates: [String] {
        switch self {
        case .script: ["Caveat", "Bradley Hand", "Bradley Hand PUA", "Snell Roundhand"]
        case .hand:   ["Shantell Sans", "Bradley Hand", "Bradley Hand PUA", "Segoe Print"]
        case .ui:     []
        }
    }

    /// The first candidate actually installed, or nil to mean "use the system face".
    var resolvedName: String? {
        candidates.first { NSFont(name: $0, size: 12) != nil }
    }

    /// The PostScript name of the family member closest to `weight`.
    ///
    /// A variable font publishes its named instances as real family members —
    /// Caveat gives `Caveat-Regular` and `CaveatRoman-Bold` — and asking for one
    /// by name is the only way a weight survives into a live window. A weight
    /// trait on the descriptor is dropped outright; a `wght` variation and
    /// SwiftUI's own `.weight()` both resolve correctly in an offscreen
    /// ImageRenderer but fall back to the regular instance on screen, which is
    /// why every offscreen check of this passed while the app drew at 400.
    func psName(for weight: NSFont.Weight) -> String? {
        guard let family = resolvedName,
              let members = NSFontManager.shared.availableMembers(ofFontFamily: family),
              !members.isEmpty
        else { return nil }

        let wanted = Face.appKitWeightClass(weight)
        var best: (name: String, distance: Int)?
        for member in members {
            guard let ps = member[0] as? String, let cls = member[2] as? Int else { continue }
            let distance = abs(cls - wanted)
            if best == nil || distance < best!.distance { best = (ps, distance) }
        }
        return best?.name
    }

    func nsFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        if let ps = psName(for: weight), let exact = NSFont(name: ps, size: size) { return exact }
        guard let name = resolvedName, let base = NSFont(name: name, size: size) else {
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
        return base
    }

    /// Named by its own face, with no weight modifier — the face carries it.
    func font(size: CGFloat, nsWeight: NSFont.Weight) -> Font {
        if let ps = psName(for: nsWeight) { return .custom(ps, fixedSize: size) }
        guard resolvedName != nil else {
            return .system(size: size, weight: nsWeight == .bold ? .bold : .regular)
        }
        return Font(nsFont(size: size, weight: nsWeight))
    }

    /// The weight classes `availableMembers(ofFontFamily:)` reports.
    static func appKitWeightClass(_ w: NSFont.Weight) -> Int {
        switch w {
        case .ultraLight: 2
        case .thin:       3
        case .light:      3
        case .medium:     6
        case .semibold:   8
        case .bold:       9
        case .heavy:      10
        case .black:      11
        default:          5
        }
    }
}

/// One entry from the type scale. `leading` is the design's line-height; the
/// modifier turns it into the lineSpacing SwiftUI actually wants, so 16/28 text
/// really does sit on a 28pt ruled line.
struct TextStyle {
    let face: Face
    let size: CGFloat
    let leading: CGFloat
    let weight: Font.Weight
    let nsWeight: NSFont.Weight
    let tracking: CGFloat

    init(_ face: Face, size: CGFloat, leading: CGFloat,
         weight: Font.Weight = .regular, nsWeight: NSFont.Weight = .regular, tracking: CGFloat = 0) {
        self.face = face
        self.size = size
        self.leading = leading
        self.weight = weight
        self.nsWeight = nsWeight
        self.tracking = tracking
    }

    var font: Font { face.font(size: size, nsWeight: nsWeight) }

    /// What the face actually occupies at this size, before any leading.
    var naturalLineHeight: CGFloat {
        let f = face.nsFont(size: size, weight: nsWeight)
        return f.ascender - f.descender + f.leading
    }

    /// How much air to add between wrapped lines to hit the design's leading.
    var lineSpacing: CGFloat { max(0, leading - naturalLineHeight) }

    /// CSS line-height centres the glyphs in the line box, putting half the
    /// leading ABOVE the first line. SwiftUI's lineSpacing only goes between
    /// lines, so without this the text rides high and stops lining up with the
    /// checkbox beside it — which is exactly the 28px-leading rule the system
    /// keeps warning about.
    var halfLeading: CGFloat { max(0, (leading - naturalLineHeight) / 2) }

    /// Half the amount a face exceeds its own line box, to pull back with
    /// negative padding — Caveat at 26pt is 32.76 tall in a 28pt box, and CSS
    /// lets the glyphs overflow rather than growing the line.
    var lineBoxTrim: CGFloat { max(0, (naturalLineHeight - leading) / 2) }

    /// Where the top of a square mark — a checkbox, the plus — must sit for its
    /// centre to land on the text's **optical** centre, midway between the
    /// baseline and the x-height.
    ///
    /// The stylesheet's flat `margin-top: 5px` centres the mark on the *line
    /// box* instead, which is 1.7pt higher, because a line box reserves ascender
    /// and descender room that lowercase handwriting never fills. Next to an
    /// 18pt box that reads as the mark floating above its own label.
    func markTop(side: CGFloat) -> CGFloat {
        let f = face.nsFont(size: size, weight: nsWeight)
        let baseline = halfLeading + f.ascender
        return baseline - f.xHeight / 2 - side / 2
    }

    /// The width a string needs for its **ink**, not just its advance.
    ///
    /// A live window rasterises a Text into a layer sized to the advance width,
    /// and a script face whose last glyph inks past that loses the overhang —
    /// Caveat overhangs by 1.46pt on "Today" and 2.03pt on "Tomorrow", which is
    /// the y's tail and the w's last stroke. Giving the Text a frame this wide
    /// puts the whole glyph inside its own layer.
    ///
    /// Trailing padding does not fix this: padding sits outside the Text's frame,
    /// so it never widens the layer that does the clipping.
    func inkWidth(of string: String) -> CGFloat {
        guard !string.isEmpty else { return 0 }
        let f = face.nsFont(size: size, weight: nsWeight)
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: string, attributes: [.font: f])
        )
        let advance = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        return max(advance, ink.origin.x + ink.width).rounded(.up)
    }

    // Marker.
    // Caveat sits low and its descenders drop about 0.3em below the baseline, so
    // every style here is leaded at 1.3x or more. Never tighten one to the cap
    // height — the tail of a y or g falls outside the line box and the first
    // container with a fixed height or a hidden overflow cuts it off.
    static let display  = TextStyle(.script, size: 44, leading: 58, weight: .bold, nsWeight: .bold)
    static let title    = TextStyle(.script, size: 26, leading: 34, weight: .bold, nsWeight: .bold)
    static let subhead  = TextStyle(.script, size: 19, leading: 26, weight: .semibold, nsWeight: .semibold)

    // Handwriting
    static let item     = TextStyle(.hand, size: 16, leading: Tk.spaceLine)
    static let body     = TextStyle(.hand, size: 15, leading: 24)
    static let scribble = TextStyle(.hand, size: 13, leading: 20)

    // Interface
    static let label    = TextStyle(.ui, size: 12, leading: 16, weight: .semibold, nsWeight: .semibold, tracking: 0.24)
    static let meta     = TextStyle(.ui, size: 11, leading: 14, weight: .medium, nsWeight: .medium)
    static let shortcut = TextStyle(.ui, size: 11, leading: 14, weight: .semibold, nsWeight: .semibold, tracking: 0.44)
    /// The count on the menu bar chip, and nothing else. The smallest type in the
    /// system, so it is numerals only — never a word.
    static let badge    = TextStyle(.ui, size: 10, leading: 12, weight: .bold, nsWeight: .bold)
}

extension View {
    func textStyle(_ s: TextStyle) -> some View {
        font(s.font)
            .lineSpacing(s.lineSpacing)
            .tracking(s.tracking)
    }
}

/// Embed the OFL files in the bundle rather than fetching them at runtime.
/// Anything in Resources/Fonts is registered before the first window is drawn.
enum Fonts {
    static func register() {
        // SwiftPM's `.process` flattens the resource folder, so the files land at
        // the bundle root rather than under Fonts/. Look in both, so this keeps
        // working if the rule ever changes to `.copy`.
        var urls: Set<URL> = []
        for ext in ["ttf", "otf", "ttc"] {
            urls.formUnion(Bundle.module.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [])
            urls.formUnion(Bundle.module.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") ?? [])
        }

        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                FileHandle.standardError.write(
                    Data("to do: could not register \(url.lastPathComponent)\n".utf8))
            }
        }
    }

    /// True once both faces are really present — used only to warn in the log.
    static var complete: Bool {
        NSFont(name: "Caveat", size: 12) != nil && NSFont(name: "Shantell Sans", size: 12) != nil
    }
}
