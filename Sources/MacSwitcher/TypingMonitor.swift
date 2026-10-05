import AppKit
import Carbon
import LayoutCore
import os

/// Следит за набором текста во всех приложениях и хранит последние набранные символы.
///
/// Работает через CGEventTap только на чтение: события не меняются и не задерживаются.
/// Для этого нужно то же разрешение «Универсальный доступ». Пароли в защищённых полях
/// macOS в event tap не отдаёт.
final class TypingMonitor {
    /// Горячая клавиша приложения: её нажатие не должно попадать в буфер (§ иначе станет символом).
    var ignoredShortcut: Shortcut?

    private(set) var buffer = TypingBuffer()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var activationObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.mortihead.MacSwitcher", category: "TypingMonitor")

    var isRunning: Bool { tap != nil }

    init() {
        // В другом приложении курсор уже в другом месте.
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.buffer.reset()
        }
    }

    deinit {
        stop()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }

    /// - Returns: `false`, если macOS не дала создать event tap (обычно нет разрешения).
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                if let userInfo {
                    Unmanaged<TypingMonitor>.fromOpaque(userInfo).takeUnretainedValue().handle(type, event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.error("Не удалось создать event tap")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
        logger.info("Event tap запущен")
        return true
    }

    func stop() {
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        runLoopSource = nil
        tap = nil
        buffer.reset()
    }

    func replaceLastWord(with replacement: String) {
        buffer.replaceLastWord(with: replacement)
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .keyDown:
            handleKeyDown(event)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // Пока tap был выключен, часть нажатий могла пройти мимо буфера.
            buffer.reset()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        default:
            // Клик мышью переносит курсор.
            buffer.reset()
        }
    }

    private func handleKeyDown(_ event: CGEvent) {
        // Свои же нажатия (⌫ и вставка перевода) не учитываем: буфер обновляется напрямую.
        if event.getIntegerValueField(.eventSourceUserData) == KeyboardEvents.marker { return }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        if let ignoredShortcut, ignoredShortcut.matches(keyCode: UInt32(keyCode), eventFlags: flags) { return }

        // ⌘ и ⌃ — команды (⌘A, ⌘Z, ⌃A...), после них неизвестно, где курсор.
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            buffer.reset()
            return
        }
        if keyCode == kVK_Delete {
            // ⌥⌫ удаляет слово целиком.
            if flags.contains(.maskAlternate) { buffer.reset() } else { buffer.deleteBackward() }
            return
        }
        if Self.breakingKeys.contains(keyCode) {
            buffer.reset()
            return
        }
        if KeyboardLayouts.isStandaloneKey(UInt32(keyCode)), keyCode != kVK_ISO_Section, keyCode != kVK_ANSI_Grave {
            return // F-клавиши текст не печатают
        }

        var length = 0
        var characters = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: characters.count, actualStringLength: &length, unicodeString: &characters)
        guard length > 0 else { return } // мёртвая клавиша, символ появится со следующим нажатием
        let string = String(utf16CodeUnits: characters, count: length)
        let isPrintable = string.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar) && !(0xF700...0xF8FF).contains(scalar.value)
        }
        if isPrintable {
            buffer.append(string)
        } else {
            buffer.reset()
        }
    }

    /// Клавиши, после которых курсор уже не в конце набранного текста.
    private static let breakingKeys: Set<Int> = [
        kVK_Return, kVK_ANSI_KeypadEnter, kVK_Tab, kVK_Escape, kVK_ForwardDelete,
        kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow,
        kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown,
    ]
}
