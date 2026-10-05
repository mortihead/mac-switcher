import AppKit

/// Иконки приложения, нарисованные кодом: в проекте нет файлов с картинками.
enum AppIcon {
    /// Значок для строки меню: буквы "A" и "Я" в рамке, как клавиша с двумя раскладками.
    /// Шаблонное изображение: macOS сама красит его под светлую и тёмную строку меню.
    static let menuBar: NSImage = {
        let image = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { rect in
            drawKey(in: rect.insetBy(dx: 1, dy: 1.5), lineWidth: 1.3, fontSize: 9.5, color: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "MacSwitcher"
        return image
    }()

    /// Крупная цветная версия для окна "О программе".
    static let large: NSImage = NSImage(size: NSSize(width: 128, height: 128), flipped: false) { rect in
        let background = NSBezierPath(roundedRect: rect.insetBy(dx: 8, dy: 8), xRadius: 26, yRadius: 26)
        NSGradient(starting: NSColor(calibratedRed: 0.30, green: 0.55, blue: 0.98, alpha: 1),
                   ending: NSColor(calibratedRed: 0.16, green: 0.32, blue: 0.80, alpha: 1))?
            .draw(in: background, angle: -90)
        drawKey(in: rect.insetBy(dx: 26, dy: 38), lineWidth: 5, fontSize: 40, color: .white)
        return true
    }

    private static func drawKey(in rect: NSRect, lineWidth: CGFloat, fontSize: CGFloat, color: NSColor) {
        let frame = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let radius = frame.height * 0.25
        let border = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
        border.lineWidth = lineWidth
        color.setStroke()
        border.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color,
            .kern: fontSize * 0.05,
        ]
        let text = NSAttributedString(string: "AЯ", attributes: attributes)
        let size = text.size()
        text.draw(at: NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2 + fontSize * 0.02))
    }
}
