import Carbon.HIToolbox

/// A system-wide keyboard shortcut.
///
/// Uses Carbon's hot-key API because it is the one route that needs no Accessibility
/// or Input Monitoring permission. The shortcut stays registered for the object's lifetime.
final class GlobalHotKey {
    enum Key: UInt32 {
        case space = 49 // kVK_Space
    }

    struct Modifiers: OptionSet {
        let rawValue: UInt32
        static let command = Modifiers(rawValue: UInt32(cmdKey))
        static let option = Modifiers(rawValue: UInt32(optionKey))
        static let control = Modifiers(rawValue: UInt32(controlKey))
        static let shift = Modifiers(rawValue: UInt32(shiftKey))
    }

    private let action: () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    /// - Returns: `nil` if the system refuses the shortcut, typically because another app owns it.
    init?(key: Key, modifiers: Modifiers, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(GetApplicationEventTarget(), hotKeyPressed, 1, &eventType, context, &handler) == noErr else {
            return nil
        }

        // "THRD": identifies this app's hot keys among the events delivered to the handler.
        let id = EventHotKeyID(signature: 0x5448_5244, id: 1)
        guard RegisterEventHotKey(key.rawValue, modifiers.rawValue, id, GetApplicationEventTarget(), 0, &hotKey) == noErr else {
            RemoveEventHandler(handler)
            return nil
        }
    }

    isolated deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }

    fileprivate func fire() { action() }
}

/// C callback for the hot-key event. Carbon delivers it on the main thread.
private nonisolated func hotKeyPressed(_: EventHandlerCallRef?, _: EventRef?, _ context: UnsafeMutableRawPointer?) -> OSStatus {
    guard let context else { return OSStatus(eventNotHandledErr) }
    nonisolated(unsafe) let pointer = context
    MainActor.assumeIsolated {
        Unmanaged<GlobalHotKey>.fromOpaque(pointer).takeUnretainedValue().fire()
    }
    return noErr
}
