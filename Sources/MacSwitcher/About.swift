import AppKit
import SwiftUI

/// Сведения о приложении: версия и ссылка на исходный код.
enum About {
    static let repositoryURL = URL(string: "https://github.com/mortihead/mac-switcher")!

    /// Версия из Info.plist. При запуске из Xcode без .app-бандла её нет.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// Стандартное окно "О программе" с описанием и ссылкой на GitHub.
    static func showPanel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)

        let credits = NSMutableAttributedString(
            string: "Исправляет текст, набранный не в той раскладке: QWERTY ⇄ ЙЦУКЕН.\n\n",
            attributes: [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
        )
        credits.append(NSAttributedString(
            string: "github.com/mortihead/mac-switcher",
            attributes: [.font: font, .link: repositoryURL, .paragraphStyle: paragraph]
        ))

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "MacSwitcher",
            .applicationVersion: version,
            .applicationIcon: AppIcon.large,
            .credits: credits,
        ])
    }
}

/// Раздел "О приложении" в окне настроек.
struct AboutSection: View {
    var body: some View {
        Section("О приложении") {
            HStack(spacing: 12) {
                Image(nsImage: AppIcon.large)
                    .resizable()
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacSwitcher \(About.version)").font(.headline)
                    Text("Исправление раскладки QWERTY ⇄ ЙЦУКЕН").foregroundStyle(.secondary)
                }
            }
            Link("Исходный код на GitHub", destination: About.repositoryURL)
        }
    }
}
