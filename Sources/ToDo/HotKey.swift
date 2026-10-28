import AppKit
import Carbon.HIToolbox

/// ⌘⇧T from anywhere. Carbon hot keys need no accessibility permission, which
/// matters for an app whose whole point is that it opens fast.
final class GlobalHotKey {
    static let shared = GlobalHotKey()

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    fileprivate var onFire: (() -> Void)?

    static let signature: OSType = 0x544F444F  // 'TODO'

    private init() {}

    /// Defaults to ⌘⇧T.
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_T),
                  modifiers: UInt32 = UInt32(cmdKey | shiftKey),
                  onFire: @escaping () -> Void) {
        self.onFire = onFire
        guard ref == nil else { return }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &spec, nil, &handler)

        let id = EventHotKeyID(signature: GlobalHotKey.signature, id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status != noErr {
            FileHandle.standardError.write(
                Data("to do: ⌘⇧T is already taken by another app (\(status))\n".utf8))
        }
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
        ref = nil
        handler = nil
    }
}

private let hotKeyHandler: EventHandlerUPP = { _, event, _ in
    var id = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject),
                      EventParamType(typeEventHotKeyID), nil,
                      MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard id.signature == GlobalHotKey.signature else { return OSStatus(eventNotHandledErr) }
    DispatchQueue.main.async { GlobalHotKey.shared.onFire?() }
    return noErr
}
