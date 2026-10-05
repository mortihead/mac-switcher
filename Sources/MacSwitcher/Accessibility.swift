import AppKit
import ApplicationServices

/// Разрешение «Универсальный доступ» (Accessibility) нужно, чтобы посылать нажатия ⌘C и ⌘V в другие приложения.
enum Accessibility {
    static func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
