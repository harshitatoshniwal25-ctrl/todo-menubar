import AppKit

/// The panel that hangs from the menu bar.
///
/// A borderless non-activating panel rather than an NSPopover: the design gives
/// the window `radius-lg` (20, so the note's 12 plus the 8 margin runs parallel
/// to it) and no arrow, and a popover's corner and arrow belong to the system,
/// not to us.
final class PanelWindow: NSPanel {
    /// Escape closes it, the same as clicking away.
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Tk.panelWidth, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true                 // shadow-popover, drawn from the clipped content
        level = .popUpMenu
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    /// The note is written in, so the panel has to take the caret.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
