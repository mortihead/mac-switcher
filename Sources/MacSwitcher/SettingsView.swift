import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Горячая клавиша") {
                ShortcutRecorder(model: model)
                if let error = model.hotKeyError {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
                Text("Нажмите сочетание сразу после набора: последнее слово переведётся, \"ghbdtn\" станет \"привет\". Повторное нажатие вернёт как было. Чтобы перевести больше, выделите текст и нажмите сочетание.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Поведение") {
                Toggle("Переключать раскладку после перевода", isOn: $model.switchLayoutAfterConversion)
                Toggle("Запускать при входе в систему", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                if let error = model.launchAtLoginError {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
            }

            Section("Разрешения") {
                if model.isAccessibilityTrusted {
                    Label("Доступ в «Универсальный доступ» выдан", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Нет доступа в «Универсальный доступ»", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Без него приложение не может скопировать и вставить выделенный текст. Включите MacSwitcher в Системных настройках → Конфиденциальность и безопасность → Универсальный доступ.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Открыть Системные настройки") { Accessibility.openSystemSettings() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Поле записи сочетания: нажимаете «Изменить», затем нужное сочетание. Esc отменяет запись.
struct ShortcutRecorder: View {
    @ObservedObject var model: AppModel
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(isRecording ? "Нажмите сочетание…" : model.shortcut.displayString)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 160, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).strokeBorder(isRecording ? Color.accentColor : Color.secondary.opacity(0.4)))
                Spacer()
                Button(isRecording ? "Отмена" : "Изменить") {
                    isRecording ? stopRecording() : startRecording()
                }
                Button("По умолчанию") { model.shortcut = .defaultShortcut }
                    .disabled(isRecording || model.shortcut == .defaultShortcut)
            }
            if let hint {
                Text(hint).font(.callout).foregroundStyle(.secondary)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        model.suspendHotKey()
        isRecording = true
        hint = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            let shortcut = Shortcut(
                keyCode: UInt32(event.keyCode),
                modifierFlags: event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
            )
            if shortcut.isValid {
                model.shortcut = shortcut
                stopRecording()
            } else {
                hint = "Добавьте ⌘ или ⌃: без них можно назначить только § и F1-F20."
            }
            return nil
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        model.resumeHotKey()
    }
}
