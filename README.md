# to do

A single sticky note that lives behind an icon in the macOS menu bar. Click the
icon, a note drops down, you write your list on it, you click away and it is gone.

Built against the **to do** design system — every colour, size, face and angle in
`Sources/ToDo/Tokens.swift` and `Typography.swift` comes from its `tokens.json`.

## Install

**Download** — grab `to-do.zip` from the
[latest release](../../releases/latest), unzip it, and drag **to do.app** into
Applications. It needs macOS 14 or later on an Apple silicon Mac.

The app is not notarized (that takes a paid Apple Developer account), so the
first time you open it macOS will refuse. Either:

- open **System Settings → Privacy & Security**, scroll down, and click
  **Open Anyway** next to "to do", or
- run `xattr -dr com.apple.quarantine "/Applications/to do.app"` in Terminal.

After that it opens normally. Right-click the menu bar icon and turn on
**Open at login** to keep it around.

**Build it yourself** — needs Xcode or the Swift command-line tools:

```
./Scripts/fetch-fonts.sh   # once — Caveat + Shantell Sans, both OFL
./Scripts/make-app.sh      # builds dist/to do.app
open "dist/to do.app"
```

Without the fonts the app still runs and falls back to Bradley Hand, per the
system's `type.families`. It logs a line to stderr when it does.

## Using it

| | |
|---|---|
| click the menu bar icon, or `⌘⇧T` | open or close the note, from anywhere |
| type on the last line, `↩` | add an item |
| click into an item's words | edit it in place — `↩` or click away keeps it, `esc` puts it back |
| click the box | strike the item — it stays put until you clear it |
| right-click an item | pin it (as many as you like), or delete it — `⌘Z` brings it back |
| right-click the paper | pick paper, or clear done items |
| right-click the icon | open at login, quit |

## Layout

```
Sources/ToDo/
  Tokens.swift        every colour, space, radius and tilt, light and dark
  Typography.swift    the three faces, the type scale, font registration
  SVGPath.swift       an SVG path reader + the six hand-drawn icons, verbatim
  Store.swift         the note, and its JSON on disk
  HotKey.swift        ⌘⇧T via Carbon (no accessibility permission needed)
  AppDelegate.swift   status item, panel window, login item
  PanelWindow.swift   the borderless panel that hangs from the menu bar
  Views/
    NotePanel.swift   paper, tape, curl, footer
    Rows.swift        an item, editable in place; the row you write the next one in
    Pieces.swift      checkbox, badge, button, empty state, paper picker
    PanelView.swift   the app's one screen, and the menu bar glyph
```

The list is stored at `~/Library/Application Support/to do/note.json`.

## Looking at it

A menu bar panel closes the moment it loses key, so it cannot be screenshotted
from a script. To check layout against the design system:

```
"dist/to do.app/Contents/MacOS/ToDo" --render /tmp/panel.png
```

Add `--dark` for the night desk, `--trigger` for the five menu bar states, and
`--live` to capture a real window instead of an offscreen render (necessary for
anything about text — the offscreen renderer resolves fonts differently). It draws the panel offscreen at 2x with sample content — never your real note —
and exits. Note that `NewItemLine` wraps an `NSTextField`, which `ImageRenderer`
cannot draw, so that one row comes out blank in the render.

To photograph the real thing instead, launch with `--pin` and the panel stays
down when it loses focus, so you can screenshot it however you like:

```
pkill -x ToDo; "dist/to do.app/Contents/MacOS/ToDo" --pin &
```

## Keeping up with the design system

`design-system.lock` records the version this repo was built against.
[DESIGN-SYNC.md](DESIGN-SYNC.md) has the procedure for pulling a newer one —
say "sync the design system" and it gets run.

## Distribution

This is not an App Store app and does not need to be. `make-app.sh` ad-hoc signs
it, which is enough for your own Mac. Removing the "Apple could not verify this
app" step for everyone else needs a Developer ID certificate ($99/yr Apple
Developer Program) and `xcrun notarytool` — no App Store review, no commission.

## Licence

The code is MIT — see [LICENSE](LICENSE). The two fonts are not part of this
repository: `fetch-fonts.sh` downloads them from Google Fonts, and each ships
with its own SIL Open Font License inside the app.

## Known gaps

- The note grows with the list rather than scrolling past a certain height.
- No app icon yet (it has no Dock presence, so this only shows in Finder).
- The menu bar count badge overlaps the glyph's corner flush with the top of the
  bar, rather than at the stylesheet's `top: -5` — a status item is 22pt tall and
  anything above that is clipped by the system.
