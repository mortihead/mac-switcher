// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacSwitcher",
    platforms: [.macOS(.v13)],
    targets: [
        // Чистая логика перевода раскладки, без зависимостей от AppKit. Покрыта тестами.
        .target(name: "LayoutCore"),
        // Само приложение в строке меню.
        .executableTarget(name: "MacSwitcher", dependencies: ["LayoutCore"]),
        .testTarget(name: "LayoutCoreTests", dependencies: ["LayoutCore"]),
    ]
)
