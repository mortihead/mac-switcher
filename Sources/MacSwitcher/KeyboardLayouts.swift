import Carbon
import Foundation
import LayoutCore

/// Работа с раскладками, установленными в системе (Text Input Sources).
enum KeyboardLayouts {
    /// Строит таблицу перевода из реальных раскладок пользователя: для каждой клавиши берём символ
    /// латинской и русской раскладки. Так учитываются и «Русская», и «Русская – ПК», и любые другие.
    static func makeConverter() -> LayoutConverter {
        guard let latin = latinLayout(), let russian = russianLayout() else { return .standard }
        var pairs: [(Character, Character)] = []
        // Коды 0–64 — основная часть клавиатуры, дальше цифровой блок и служебные клавиши.
        for keyCode in UInt16(0)..<UInt16(65) {
            for shift in [false, true] {
                guard let latinCharacter = character(in: latin, keyCode: keyCode, shift: shift),
                      let russianCharacter = character(in: russian, keyCode: keyCode, shift: shift),
                      latinCharacter != russianCharacter else { continue }
                pairs.append((latinCharacter, russianCharacter))
            }
        }
        return pairs.count >= 30 ? LayoutConverter(pairs: pairs) : .standard
    }

    /// Включает раскладку, в которую был переведён текст.
    static func select(for direction: LayoutConverter.Direction) {
        let source = direction == .toCyrillic ? russianLayout() : latinLayout()
        if let source { TISSelectInputSource(source) }
    }

    /// Последняя использованная латинская (ASCII) раскладка: U.S., ABC и т. п.
    static func latinLayout() -> TISInputSource? {
        TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
    }

    /// Первая включённая русская раскладка.
    static func russianLayout() -> TISInputSource? {
        enabledKeyboardLayouts().first { source in
            let languages = property(of: source, kTISPropertyInputSourceLanguages) as? [String] ?? []
            return languages.first?.hasPrefix("ru") == true
        }
    }

    static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        functionKeys.contains(Int(keyCode))
    }

    /// Название клавиши для отображения сочетания: «X», «Space», «F5».
    static func keyName(for keyCode: UInt32) -> String {
        if let name = specialKeyNames[Int(keyCode)] { return name }
        if let latin = latinLayout(), let character = character(in: latin, keyCode: UInt16(keyCode), shift: false) {
            return String(character).uppercased()
        }
        return "#\(keyCode)"
    }

    // MARK: - Private

    private static func enabledKeyboardLayouts() -> [TISInputSource] {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false) else { return [] }
        return list.takeRetainedValue() as! [TISInputSource]
    }

    private static func property(of source: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }

    /// Какой символ печатает клавиша `keyCode` в раскладке `source`.
    private static func character(in source: TISInputSource, keyCode: UInt16, shift: Bool) -> Character? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Character? in
            guard let base = raw.baseAddress else { return nil }
            let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKeyState: UInt32 = 0
            var length = 0
            var buffer = [UniChar](repeating: 0, count: 4)
            let modifierState: UInt32 = shift ? UInt32((shiftKey >> 8) & 0xFF) : 0
            let status = UCKeyTranslate(
                layout,
                keyCode,
                UInt16(kUCKeyActionDown),
                modifierState,
                UInt32(LMGetKbdType()),
                OptionBits(1 << kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                buffer.count,
                &length,
                &buffer
            )
            guard status == noErr, length == 1 else { return nil }
            let string = String(utf16CodeUnits: buffer, count: length)
            guard let character = string.first,
                  !character.isWhitespace,
                  !string.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
            else { return nil }
            return character
        }
    }

    private static let functionKeys: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    private static let specialKeyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18",
        kVK_F19: "F19", kVK_F20: "F20",
    ]
}
