import AppKit
import ServiceManagement

/// Состояние приложения и настройки (хранятся в UserDefaults).
@MainActor
final class AppModel: ObservableObject {
    @Published var shortcut: Shortcut {
        didSet {
            if let data = try? JSONEncoder().encode(shortcut) {
                defaults.set(data, forKey: Keys.shortcut)
            }
            registerHotKey()
        }
    }

    @Published var switchLayoutAfterConversion: Bool {
        didSet { defaults.set(switchLayoutAfterConversion, forKey: Keys.switchLayout) }
    }

    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var launchAtLoginError: String?
    @Published private(set) var hotKeyError: String?
    @Published private(set) var isAccessibilityTrusted = Accessibility.isTrusted(prompt: false)

    private enum Keys {
        static let shortcut = "shortcut"
        static let switchLayout = "switchLayoutAfterConversion"
    }

    private let defaults = UserDefaults.standard
    private let hotKeys = HotKeyManager()
    private let selectionConverter = SelectionConverter()
    private var isHotKeySuspended = false
    private var accessibilityPolling: Task<Void, Never>?

    init() {
        if let data = defaults.data(forKey: Keys.shortcut),
           let saved = try? JSONDecoder().decode(Shortcut.self, from: data) {
            shortcut = saved
        } else {
            shortcut = .defaultShortcut
        }
        switchLayoutAfterConversion = defaults.object(forKey: Keys.switchLayout) as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled

        hotKeys.onPress = { [weak self] in self?.convertSelection() }
        registerHotKey()

        // Разрешение выдаётся в Системных настройках, пока приложение работает, поэтому проверяем его периодически.
        accessibilityPolling = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.refreshAccessibility()
            }
        }
    }

    func convertSelection() {
        refreshAccessibility()
        guard isAccessibilityTrusted else {
            requestAccessibility()
            return
        }
        let switchLayout = switchLayoutAfterConversion
        Task { await selectionConverter.convertSelection(switchLayout: switchLayout) }
    }

    func requestAccessibility() {
        isAccessibilityTrusted = Accessibility.isTrusted(prompt: true)
    }

    func refreshAccessibility() {
        let trusted = Accessibility.isTrusted(prompt: false)
        if trusted != isAccessibilityTrusted { isAccessibilityTrusted = trusted }
    }

    /// Пока пользователь записывает новое сочетание, старое не должно срабатывать.
    func suspendHotKey() {
        isHotKeySuspended = true
        hotKeys.unregister()
    }

    func resumeHotKey() {
        isHotKeySuspended = false
        registerHotKey()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Не получилось: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func registerHotKey() {
        guard !isHotKeySuspended else { return }
        hotKeyError = hotKeys.register(shortcut)
            ? nil
            : "Сочетание \(shortcut.displayString) занято или запрещено системой"
    }
}
