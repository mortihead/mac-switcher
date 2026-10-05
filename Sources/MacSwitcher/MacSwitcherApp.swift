import AppKit
import SwiftUI

/// Точка входа. Приложение живёт только в строке меню: без окна и без иконки в Dock.
@main
struct MacSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: appDelegate.model, openSettings: appDelegate.showSettings)
        } label: {
            Image(nsImage: AppIcon.menuBar)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // lazy: модель создаётся при первом обращении, уже на главном потоке.
    lazy var model = AppModel()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Info.plist уже содержит LSUIElement, но при запуске без .app-бандла (из Xcode) нужно и это.
        NSApp.setActivationPolicy(.accessory)
        if !model.isAccessibilityTrusted {
            showSettings()
            model.requestAccessibility()
        }
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "Настройки MacSwitcher"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel
    let openSettings: @MainActor () -> Void

    var body: some View {
        Button("Перевести выделенный текст") {
            model.convertSelection()
        }
        if !model.isAccessibilityTrusted {
            Button("⚠️ Нужен доступ в «Универсальный доступ»…") {
                model.requestAccessibility()
            }
        }
        if let error = model.hotKeyError {
            Text("⚠️ \(error)")
        }
        Divider()
        Button("О MacSwitcher") { About.showPanel() }
        Button("Настройки…") { openSettings() }
            .keyboardShortcut(",")
        Divider()
        Button("Выйти из MacSwitcher") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
