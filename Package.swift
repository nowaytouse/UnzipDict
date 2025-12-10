// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "UnzipDict",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "UnzipDict",
            path: "Sources",
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)
