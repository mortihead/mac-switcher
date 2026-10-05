import XCTest
@testable import LayoutCore

final class TypingBufferTests: XCTestCase {
    func testLastWordWithTrailingSpaces() {
        var buffer = TypingBuffer()
        buffer.append("hello ")
        buffer.append("ghbdtn")
        XCTAssertEqual(buffer.lastWord, "ghbdtn")
        buffer.append("  ")
        XCTAssertEqual(buffer.lastWord, "ghbdtn  ", "пробелы после слова тоже переводятся (остаются как есть)")
    }

    func testPunctuationIsPartOfWord() {
        var buffer = TypingBuffer()
        buffer.append("nj;t")
        XCTAssertEqual(buffer.lastWord, "nj;t", "; на русской раскладке это буква ж, слово не должно разрываться")
    }

    func testNoWord() {
        var buffer = TypingBuffer()
        XCTAssertNil(buffer.lastWord)
        buffer.append("   ")
        XCTAssertNil(buffer.lastWord)
    }

    func testDeleteBackwardAndReset() {
        var buffer = TypingBuffer()
        buffer.append("ghbdtnn")
        buffer.deleteBackward()
        XCTAssertEqual(buffer.lastWord, "ghbdtn")
        buffer.reset()
        XCTAssertNil(buffer.lastWord)
        buffer.deleteBackward()
        XCTAssertEqual(buffer.text, "")
    }

    func testLimit() {
        var buffer = TypingBuffer(limit: 5)
        buffer.append("abc def")
        XCTAssertEqual(buffer.text, "c def")
    }

    func testReplaceLastWord() {
        var buffer = TypingBuffer()
        buffer.append("hello ghbdtn ")
        buffer.replaceLastWord(with: "привет ")
        XCTAssertEqual(buffer.text, "hello привет ")
        XCTAssertEqual(buffer.lastWord, "привет ")
    }
}
