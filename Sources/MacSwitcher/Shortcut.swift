import AppKit
import Carbon

/// Сочетание клавиш: виртуальный код клавиши плюс модификаторы.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    /// `NSEvent.ModifierFlags.rawValue`.
    var modifierFlags: UInt

    /// ⌃⌥X по умолчанию. Сочетания только с ⌥ или ⌥⇧ macOS 15 запрещает регистрировать.
    static let defaultShortcut = Shortcut(
        keyCode: UInt32(kVK_ANSI_X),
        modifierFlags: NSEvent.ModifierFlags([.control, .option]).rawValue
    )

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags).intersection([.command, .option, .control, .shift])
    }

    var carbonModifiers: UInt32 {
        var result = 0
        if modifiers.contains(.command) { result |= cmdKey }
        if modifiers.contains(.option) { result |= optionKey }
        if modifiers.contains(.control) { result |= controlKey }
        if modifiers.contains(.shift) { result |= shiftKey }
        return UInt32(result)
    }

    /// Нужен ⌘ или ⌃, иначе сочетание мешает обычному набору текста. F-клавиши можно без модификаторов.
    var isValid: Bool {
        modifiers.contains(.command) || modifiers.contains(.control) || KeyboardLayouts.isFunctionKey(keyCode)
    }

    var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + KeyboardLayouts.keyName(for: keyCode)
    }
}
