/// Переводит текст, набранный не в той раскладке: QWERTY ⇄ ЙЦУКЕН.
///
/// Конвертер хранит пары «символ латинской раскладки ↔ символ русской раскладки»,
/// которые получаются нажатием одной и той же физической клавиши.
public struct LayoutConverter: Sendable {
    public enum Direction: Sendable, Equatable {
        /// Текст набран в латинской раскладке, а должен быть русским: «ghbdtn» → «привет».
        case toCyrillic
        /// Текст набран в русской раскладке, а должен быть латинским: «руддщ» → «hello».
        case toLatin
    }

    private let latinToCyrillic: [Character: Character]
    private let cyrillicToLatin: [Character: Character]

    /// - Parameter pairs: пары (латинский символ, русский символ) для одной клавиши.
    ///   Если символ встречается несколько раз, используется первая пара.
    public init(pairs: [(Character, Character)]) {
        var forward: [Character: Character] = [:]
        var backward: [Character: Character] = [:]
        for (latin, cyrillic) in pairs {
            if forward[latin] == nil { forward[latin] = cyrillic }
            if backward[cyrillic] == nil { backward[cyrillic] = latin }
        }
        latinToCyrillic = forward
        cyrillicToLatin = backward
    }

    /// Раскладки «U.S.» и «Russian – PC» (стандартная ЙЦУКЕН, как в Windows).
    /// Используется, если не удалось прочитать раскладки, установленные в системе.
    public static let standard: LayoutConverter = {
        let latin = "qwertyuiop[]asdfghjkl;'zxcvbnm,./`"
            + "QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>?~"
            + "@#$^&|"
        let cyrillic = "йцукенгшщзхъфывапролджэячсмитьбю.ё"
            + "ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,Ё"
            + "\"№;:?/"
        assert(latin.count == cyrillic.count)
        return LayoutConverter(pairs: Array(zip(latin, cyrillic)))
    }()

    /// Угадывает направление перевода: если русских букв больше, чем латинских,
    /// текст переводится в латиницу, иначе в кириллицу.
    public func detectDirection(_ text: String) -> Direction {
        var latin = 0
        var cyrillic = 0
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x41...0x5A, 0x61...0x7A: latin += 1
            case 0x0400...0x04FF: cyrillic += 1
            default: break
            }
        }
        return cyrillic > latin ? .toLatin : .toCyrillic
    }

    /// Переводит текст. Символы, которых нет в таблице (цифры, пробелы, эмодзи), не меняются.
    /// - Parameter direction: направление; если `nil`, определяется через `detectDirection`.
    public func convert(_ text: String, direction: Direction? = nil) -> String {
        let map = (direction ?? detectDirection(text)) == .toCyrillic ? latinToCyrillic : cyrillicToLatin
        return String(text.map { map[$0] ?? $0 })
    }
}
