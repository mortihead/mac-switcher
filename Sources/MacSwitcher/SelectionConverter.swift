import AppKit
import Carbon
import LayoutCore

/// Переводит выделенный или только что набранный текст в активном приложении.
///
/// Универсального способа прочитать выделение во всех программах нет, поэтому делаем как Punto Switcher:
/// копируем выделение (⌘C), переводим, вставляем обратно (⌘V) и восстанавливаем прежний буфер обмена.
/// Набранный текст берётся из `TypingMonitor`, стирается нажатиями ⌫ и печатается заново.
@MainActor
final class SelectionConverter {
    private var isRunning = false

    /// Заменяет только что набранный `typed` (он стоит прямо перед курсором) на перевод.
    /// - Returns: перевод или `nil`, если переводить нечего.
    func convertTyped(_ typed: String, switchLayout: Bool) async -> String? {
        guard !isRunning else { return nil }
        isRunning = true
        defer { isRunning = false }

        let converter = KeyboardLayouts.makeConverter()
        let direction = converter.detectDirection(typed)
        let converted = converter.convert(typed, direction: direction)
        guard converted != typed else {
            NSSound.beep()
            return nil
        }

        // С зажатым ⌘ или ⌥ клавиша ⌫ удалила бы строку или слово целиком.
        await waitForModifierKeysRelease()

        KeyboardEvents.press(CGKeyCode(kVK_Delete), flags: [], count: typed.count)
        KeyboardEvents.type(converted)
        if switchLayout {
            KeyboardLayouts.select(for: direction)
        }
        return converted
    }

    func convertSelection(switchLayout: Bool) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        // Пока пользователь держит модификаторы горячей клавиши, ⌘C превратился бы, например, в ⌃⌥⌘C.
        await waitForModifierKeysRelease()

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        let changeCount = pasteboard.changeCount

        KeyboardEvents.press(CGKeyCode(kVK_ANSI_C), flags: .maskCommand)

        guard await waitForPasteboardChange(pasteboard, from: changeCount) else {
            // Буфер не изменился: скорее всего, ничего не выделено.
            NSSound.beep()
            return
        }
        guard let selected = pasteboard.string(forType: .string), !selected.isEmpty else {
            snapshot.restore(to: pasteboard)
            NSSound.beep()
            return
        }

        let converter = KeyboardLayouts.makeConverter()
        let direction = converter.detectDirection(selected)
        let converted = converter.convert(selected, direction: direction)
        guard converted != selected else {
            snapshot.restore(to: pasteboard)
            return
        }

        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(converted, forType: .string)
        // Подсказка менеджерам буфера обмена не сохранять эту временную запись в историю.
        item.setData(Data(), forType: .transient)
        pasteboard.writeObjects([item])

        KeyboardEvents.press(CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
        if switchLayout {
            KeyboardLayouts.select(for: direction)
        }

        // Даём приложению время забрать текст из буфера, прежде чем вернуть старое содержимое.
        try? await Task.sleep(nanoseconds: 400_000_000)
        snapshot.restore(to: pasteboard)
    }

    private func waitForModifierKeysRelease(timeout: TimeInterval = 1) async {
        let deadline = Date().addingTimeInterval(timeout)
        let modifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        while Date() < deadline {
            if CGEventSource.flagsState(.combinedSessionState).intersection(modifiers).isEmpty { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func waitForPasteboardChange(_ pasteboard: NSPasteboard, from changeCount: Int, timeout: TimeInterval = 0.6) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pasteboard.changeCount != changeCount { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return pasteboard.changeCount != changeCount
    }
}

private extension NSPasteboard.PasteboardType {
    static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
}

/// Копия всего содержимого буфера обмена (все элементы и все их типы).
private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { contents[type] = data }
            }
            return contents
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored = items.map { contents -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in contents { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}

/// Имитация нажатий клавиш. Требует разрешения «Универсальный доступ».
enum KeyboardEvents {
    /// Метка в `eventSourceUserData`, по которой `TypingMonitor` отличает свои события от нажатий пользователя.
    static let marker: Int64 = 0x4D53_5754 // 'MSWT'

    static func press(_ keyCode: CGKeyCode, flags: CGEventFlags, count: Int = 1) {
        let source = makeSource()
        for _ in 0..<count {
            for keyDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else { continue }
                event.flags = flags
                event.post(tap: .cghidEventTap)
            }
        }
    }

    /// Печатает текст независимо от текущей раскладки: символы передаются в событии напрямую.
    static func type(_ text: String) {
        let source = makeSource()
        for character in text {
            let utf16 = Array(String(character).utf16)
            for keyDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown) else { continue }
                event.flags = []
                event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                event.post(tap: .cghidEventTap)
            }
        }
    }

    private static func makeSource() -> CGEventSource? {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.userData = marker
        return source
    }
}
