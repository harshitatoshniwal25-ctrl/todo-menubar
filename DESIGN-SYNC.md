# Keeping this repo in step with the design system

The design system lives at
<https://claude.ai/code/artifact/4998811f-33da-49ce-a803-afc59484484b>
(namespace `ToDo`, global `window.ToDo`). `design-system.lock` records the
version this repo and the canvas were last built against.

There is no push notification when an Artifact changes, so this is a poll:
compare the artifact's current version against the lock.

## The procedure

1. **Check.** List the artifact's files. The result carries its version id
   (`version 1789988458-56f2`). If it matches `design-system.lock`, stop —
   nothing to do, and say so rather than making a no-op commit.
2. **Read what moved.** Compare file sizes against the previous listing to see
   which files changed, then read `project/design-system.json` first — its
   `lastChange.note` is a written changelog of the edit. Then read
   `project/tokens.json`, `project/README.md`, and the `README.md` of any
   component whose size changed. Read `project/components/bundle.css` too: the
   Swift is a hand port of it, so a rule added or dropped there is a real change.
3. **Apply to the app.**
   - `Sources/ToDo/Tokens.swift` holds every colour, space, radius and tilt.
     Paper tokens and pens use `fixed()`; only the desk and its chrome use
     `dyn()`. Keep that split — it is what enforces the two-grounds rule.
   - `Sources/ToDo/Typography.swift` holds the type scale.
   - Component rules live in `Sources/ToDo/Views/`. The component READMEs are
     the spec; follow them over anything inferred from the bundle.
4. **Apply to the canvas** at <https://claude.ai/artifact/7wjSzD6re3HuW9HsvN89mU>.
   - `canvas/project/theme.css` mirrors `tokens.json` as CSS variables. The
     system ships no `tokens.css`, so this file is the only place the bundle's
     variables are defined — a token added there has to be added here.
   - Re-copy `tokens.json`, `components/bundle.{js,css}` and `index.d.ts` into
     `project/ds/todo/`, and bump `version` + `copiedAt` in the `designSystems`
     record in `canvas/project/canvas.json`.
   - The copies were published by a previous session, so the publish guard will
     refuse them as unread. That is expected: name those four paths in
     `overwrite_unread`, since replacing them *is* the update.
5. **Rebuild and restart.**
   ```
   pkill -x ToDo; ./Scripts/make-app.sh && open "dist/to do.app"
   ```
6. **Update the lock** with the new version id and the time.
7. **Report** what changed in the system and what it forced here — especially
   anything that could not be honoured, and any place the component cards and
   `tokens.json` disagree.

## Where the system contradicts itself

Found during a full audit. None are bugs in the app — they are places two parts
of the system disagree, and the choice made here is written down so it does not
get silently flipped back. `bundle.css` was treated as the tiebreaker, since it
is generated from the same source as the components.

| Rule | Conflicts with | What this code does |
|---|---|---|
| `PaperSwatches` card: swatches are `radius-note` | `tokens.json` + `bundle.css`: `radius-md` on paper swatches | `radius-md` (8). At 12 a 30px swatch reads as a blob. |
| README: "never tilt a control smaller than 32px" | `bundle.css` tilts the 30px swatches, and the card describes it | Tilts them. The ring, not the tilt, carries selection, so nothing is lost for a pointer. |
| `tokens.json`: `space-1` is "gap between a checkbox and its label" | `bundle.css`: the row's gap is `space-2`, and `space-1` is its padding | `space-2` gap, `space-1` padding. |
| README: every interactive element takes a 2px focus ring | `NewItemLine` card: "no border … the only chrome is the plus" | No ring on the field. The plus turning `pen-blue` and the `pen-blue` caret are its focus state. Everything else has a ring. |
| README: "reserve `ink-faint` for the ruled lines, dividers and a disabled checkbox outline" | The ruling is gone, and `hairline` owns dividers | `ink-faint` on the disabled checkbox and the resting plus, per the token's own usage note. |

The menu bar badge is a scrap of the open note's paper in `radius-sm`, 14px
square, set in the `badge` style, always in `ink` — there is no overdue state
and no red tone (removed 2026-09-24, in the app and the design system). It is not tilted — at 14px a
rotation pushes a corner out of the button's box. `radius-pill` was removed from
the tokens, so nothing here should reference it again.

The Marker styles are leaded at 1.3x or more (title 26/34, display 44/58) because
Caveat's descenders drop about 0.3em below the baseline. Never tighten one to the
cap height and never constrain a heading's height: the tail of a y or g falls
outside the line box and the first fixed-height or clipped container eats it.
That is what was cutting the y in "Today".

`pen-green` is the one token with no home in the app. The system gives it "the
completed count and the saved confirmation", and neither exists here — the
footer count is the *remaining* count, which belongs in `ink-muted`. Rather than
invent a surface for it, `Tk.Paper.countInk` encodes the pen-green-on-mint rule
and waits.

## Where this app deliberately differs from the system

| | stylesheet | here | why |
|---|---|---|---|
| note padding-top | `space-4` (16) | `space-5` (24) | sits the heading lower, clear of the tape |

The gap under the title is no longer a deviation: `.tk-note__title`'s margin was
changed to `space-2` in the system itself, and the app follows it. The one
difference left is a token step, not a loose number. If it is right, fold it into
`.tk-note` so the system and the app agree; until then a sync will not overwrite
it, but it will keep showing up as a difference.

## Per-paper accent and highlight

Each paper has its own `accent-*` (tick, caret, focus ring, primary button, the
selected swatch's ring) and `highlight-*` (the pinned swipe). In Swift they are
`Tk.Paper.accent` and `Tk.Paper.highlight`; `NotePanel` hands the accent down as
the `noteAccent` environment value, the way the stylesheet sets `--tk-accent`.
Links on paper stay `pen-blue`; the empty checkbox stays `ink-muted` on every
paper.

## Where the right-click catchers sit

Rows each carry a `RightClickCatcher` as an overlay. The paper's catcher is a
background of the note's *content*, placed **above** `paper.color` and below the
rows. Put it behind the paper and the SwiftUI paper wins every hit test on bare
paper, so Pick paper never opens. The heading is `allowsHitTesting(false)` for
the same reason: an `NSTextField` label swallows a right-click on its text.

## Testing a click for real

`--test-right-click` right-clicks the heading, bare paper, an item and the
footer through AppKit's real event queue — posted, then dequeued with a mask for
right-clicks only, so `NSApp.currentEvent` is set and the hit test is genuine —
and fails if any spot opens no menu. Handing an event straight to a view skips
the hit test, which is exactly the part that breaks.



`--test-picker-flow` right-clicks the paper, chooses Pick paper and clicks a
swatch, all as synthesised events routed through AppKit, and exits non-zero if
the paper does not change. Offscreen renders cannot tell you whether something
is clickable; this can.

## The row menu

`TodoItem`'s right-click menu is `RowMenu`, a SwiftUI overlay in
`Views/RowMenu.swift` — not a `.contextMenu`. It has to be: the system menu
cannot be given `chrome-danger`, and a destructive row in `pen-red` only reaches
2.3:1 on the dark menu. That is the single easiest mistake to make here.

`RightClickCatcher` is the only way to get a right-click position out of SwiftUI
on macOS. It overlays the row and is invisible to left clicks — its `hitTest`
returns nil unless `NSApp.currentEvent` is a right-click or a ctrl-click — so the
checkbox underneath still works. Remove that override and the checkboxes stop
responding.

Two SwiftUI traps in placing it, both of which put the menu outside the panel:

- `.overlay(alignment:)` does **not** reach a `@ViewBuilder` that returns more
  than one view — it centres them. The offset then lands half a panel to the
  right. Wrap the contents in an explicit `ZStack(alignment: .topLeading)`.
- A panel height tracked in `@State` is still zero on the frame the menu first
  appears, so every clamp collapses to the top edge. Place the menu inside a
  `GeometryReader` and use its height.

- An `NSHostingView` is already flipped (top-down). Converting a click into it
  and then flipping again mirrors the point about the panel's middle — the menu
  opened ~55pt from the pointer, nowhere near its item. `--test-row-menu`
  right-clicks the second item and fails if the menu opens more than 4pt away.

The window ends at the paper's edge, so a menu that does not fit is simply cut
off — it flips above the pointer when there is no room below, and clamps to the
panel either way.

Deleting is immediate, which the system allows only because it is reversible:
`Store` keeps the removed item for six seconds, the footer shows
`1 deleted · undo` in `meta` for that long, and ⌘Z restores it.

## Things that have bitten before

- A conflict between a component card and `tokens.json` is worth flagging rather
  than silently picking one. `bundle.css` is the tiebreaker: it is generated
  from the same source the components are.
- `NSPopover` cannot take a custom corner radius, which is why the panel is a
  borderless `NSPanel`. If `radius-lg` moves again, only `PanelWindow` and
  `PanelView`'s `clipShape` need to change.
- The menu bar badge overlaps the trigger's top-right corner, as the stylesheet
  has it, but flush with the top rather than at `top: -5`: a status item is 22pt
  tall and the bar clips anything above that. The horizontal `right: -6` is kept
  exactly.
- Nothing in the trigger may extend beyond its own 22pt box — the menu bar runs
  along the top edge of the screen and clips anything above it. With a count the
  button widens 28 → 34 and the glyph shifts left so the chip gets its own
  corner, rather than the chip rising out of the box. (An earlier version of this
  app did let it rise; the system settled the question the other way.)
- Check the trigger with `--render <path> --trigger`, which lays the five states
  out the way the system's own MenubarTrigger preview card does. Measured against
  it: fill 28x22, badge 17x17, badge top -5.
- `NSStatusItem.variableLength` sizes the button from its image or title. This
  button has neither — the glyph is a SwiftUI subview — so it collapses and
  squeezes whatever is inside. `fitStatusItem()` sets `length` from the
  composite's real width and re-runs when the badge appears or goes. Never
  constrain the hosting view to the button's width; it is the button that has to
  follow the glyph.
- SwiftUI's `foregroundStyle` does not reach an editable text field's text on
  macOS, and nor does a `prompt`'s colour. Both fall back to the system label
  colours, which are near-white in dark mode — so the handwriting came out white
  on yellow paper. `NoteTextField` is an `NSViewRepresentable` for exactly this:
  `textColor`, the placeholder attributes and `insertionPointColor` are set
  directly. Do not "simplify" it back to a SwiftUI `TextField`.
- CSS `line-height` centres glyphs in the line box; SwiftUI's `lineSpacing` only
  adds space *between* lines. `TextStyle.halfLeading` supplies the space CSS puts
  above the first line. Without it every line rides high and stops aligning with
  its checkbox. Where a face is *taller* than its line box — Caveat at 26pt is
  32.76 against 28 — the text is framed to the box and allowed to overflow,
  again matching CSS.
- The shared field editor indents text by `lineFragmentPadding` (2pt); the
  cell's placeholder does not. So an `NSTextField` shifts its text 2pt right the
  instant it gains focus, out of line with every row above it. `CaretTextField`
  zeroes it on becoming first responder *and* on every update, because the
  editor is shared and recycled between fields.
- Caveat carries its tails outside the advance width its layout reserves —
  1.46pt on "Today", 2.13pt on "Tonight" — so SwiftUI clips the last glyph.
  `TextStyle.rightOverhang(of:)` measures it per string and it is added as
  trailing room. Shantell Sans measures *negative*, so list lines never need it.
- Framing a Text to a height smaller than the face needs clips it. To hold a
  heading to a line box shorter than its natural height, use negative vertical
  padding (`lineBoxTrim`) so the glyphs overflow instead, which is what CSS
  line-height does.
- **Ask for a weight by PostScript face name, never by weight.** Caveat and
  Shantell Sans are variable fonts, and on those: a weight trait on an
  `NSFontDescriptor` is dropped outright; a `wght` variation and SwiftUI's
  `.weight()` both resolve correctly in an offscreen `ImageRenderer` but fall
  back to the *regular* instance in a live window. So every offscreen check
  passed while the app on screen drew Caveat at 400 instead of 700 — which is
  what made the y in "Today" look wrong for so long. The fix is
  `Face.psName(for:)`, which picks the family member closest to the wanted
  weight (`CaveatRoman-Bold`, `ShantellSans-Light_Regular`) and hands that name
  to `Font.custom` with no weight modifier. Caveat 700 inks 46.54 x 23.63
  against 400's 45.34 x 23.04, so this is measurable, not cosmetic.
- **A live window rasterises a SwiftUI `Text` into a layer sized to the string's
  advance width, and clips whatever inks past it.** Caveat overhangs its advance
  by ~1.5pt on "Today" — the tail of the y — so the tail was cut on screen while
  every offscreen render showed it whole. Widening the SwiftUI frame does not
  help; the frame is not what sizes the layer. The heading is therefore a
  `NoteHeading` (`NSTextField`) sized to `TextStyle.inkWidth(of:)`. Measured in a
  live window: SwiftUI Text 45.00x23.50 against the face's real 46.54x23.63;
  the AppKit heading 47.00x24.00, complete.
- Use `--render <path> --live` to check anything about text. It builds a real
  `PanelWindow` and captures it through AppKit's own drawing, so it goes through
  the on-screen path. `--render` alone uses `ImageRenderer`, which does not.
- A corollary: **an offscreen render is not proof for anything font-related.**
  `--render` is right about layout and colour; for weight, measure a screenshot
  of the running app against the face's own metrics.
- SwiftPM's `.process` rule flattens the resource folder: `Resources/Fonts/x.ttf`
  is served at the bundle root, not under `Fonts/`. `Fonts.register()` looks in
  both. A silent stderr at launch means both faces registered; the warning line
  means it fell back to Bradley Hand.
