import Carbon

/// Глобальная горячая клавиша через Carbon `RegisterEventHotKey`.
/// Этот API не требует отдельного разрешения и срабатывает в любом приложении.
final class HotKeyManager {
    var onPress: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in manager.onPress?() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    deinit {
        unregister()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    /// - Returns: `false`, если система не дала зарегистрировать сочетание.
    @discardableResult
    func register(_ shortcut: Shortcut) -> Bool {
        unregister()
        let hotKeyID = EventHotKeyID(signature: OSType(0x4D53_5754), id: 1) // 'MSWT'
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
