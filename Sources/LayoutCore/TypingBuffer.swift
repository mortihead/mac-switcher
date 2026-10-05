/// Текст, набранный пользователем с момента последнего "разрыва": клика мышью, стрелок, Return,
/// переключения приложения и т. п. Из него берётся последнее слово для перевода без выделения.
public struct TypingBuffer: Sendable {
    public private(set) var text = ""
    private let limit: Int

    /// - Parameter limit: сколько последних символов хранить.
    public init(limit: Int = 256) {
        self.limit = limit
    }

    public mutating func append(_ string: String) {
        text += string
        if text.count > limit {
            text = String(text.suffix(limit))
        }
    }

    public mutating func deleteBackward() {
        if !text.isEmpty { text.removeLast() }
    }

    public mutating func reset() {
        text = ""
    }

    /// Последнее слово вместе с пробелами после него: для "hello ghbdtn " это "ghbdtn ".
    /// Словом считается всё между пробелами, поэтому "nj;t" (тоже) не разрывается на ";".
    /// `nil`, если в буфере только пробелы или он пуст.
    public var lastWord: String? {
        var start = text.endIndex
        while start > text.startIndex, text[text.index(before: start)].isWhitespace {
            start = text.index(before: start)
        }
        let wordEnd = start
        while start > text.startIndex, !text[text.index(before: start)].isWhitespace {
            start = text.index(before: start)
        }
        return start < wordEnd ? String(text[start...]) : nil
    }

    /// Заменяет `lastWord` на `replacement`, чтобы повторное нажатие перевело слово обратно.
    public mutating func replaceLastWord(with replacement: String) {
        guard let word = lastWord else { return }
        text.removeLast(word.count)
        text += replacement
    }
}
