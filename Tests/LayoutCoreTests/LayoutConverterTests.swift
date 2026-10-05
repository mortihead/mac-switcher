import XCTest
@testable import LayoutCore

final class LayoutConverterTests: XCTestCase {
    private let converter = LayoutConverter.standard

    func testLatinToCyrillic() {
        XCTAssertEqual(converter.convert("ghbdtn"), "привет")
        XCTAssertEqual(converter.convert("Ghbdtn? vbh!"), "Привет, мир!")
        XCTAssertEqual(converter.convert("nj;t"), "тоже")
        XCTAssertEqual(converter.convert("`krf"), "ёлка")
    }

    func testCyrillicToLatin() {
        XCTAssertEqual(converter.convert("руддщ"), "hello")
        XCTAssertEqual(converter.convert("Руддщб Цщкдв"), "Hello, World")
    }

    func testDetectDirection() {
        XCTAssertEqual(converter.detectDirection("ghbdtn"), .toCyrillic)
        XCTAssertEqual(converter.detectDirection("руддщ"), .toLatin)
        XCTAssertEqual(converter.detectDirection("123"), .toCyrillic)
        // Латинских букв больше: уже русская часть остаётся как есть.
        XCTAssertEqual(converter.convert("Ghbdtn мир"), "Привет мир")
    }

    func testExplicitDirection() {
        XCTAssertEqual(converter.convert("hello", direction: .toLatin), "hello")
        XCTAssertEqual(converter.convert("руддщ", direction: .toCyrillic), "руддщ")
    }

    func testDigitsAndSpacesAreKept() {
        XCTAssertEqual(converter.convert("123 abc\n"), "123 фис\n")
        XCTAssertEqual(converter.convert(""), "")
    }

    func testRoundTrip() {
        let latin = "qwertyuiop[]asdfghjkl;'zxcvbnm,./`QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>?~@#$^&|"
        let cyrillic = converter.convert(latin, direction: .toCyrillic)
        XCTAssertEqual(converter.convert(cyrillic, direction: .toLatin), latin)
    }

    func testFirstPairWins() {
        let custom = LayoutConverter(pairs: [(".", "ю"), (".", ","), ("/", ".")])
        XCTAssertEqual(custom.convert(".", direction: .toCyrillic), "ю")
        XCTAssertEqual(custom.convert(".", direction: .toLatin), "/")
    }
}
