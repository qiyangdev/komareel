// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KomareelScript",
    platforms: [.iOS(.v17), .macOS(.v15)],
    products: [
        .library(name: "CKomareelScript", targets: ["CKomareelScript"]),
        .library(name: "KomareelSourceKit", targets: ["KomareelSourceKit"])
    ],
    targets: [
        .target(
            name: "CKomareelScript",
            exclude: ["QuickJS/LICENSE"],
            cSettings: [.headerSearchPath("QuickJS")]
        ),
        .target(name: "KomareelSourceKit")
    ],
    swiftLanguageModes: [.v5]
)
