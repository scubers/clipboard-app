// swift-tools-version: 5.9
import PackageDescription

// Carbon is needed for RegisterEventHotKey

let package = Package(
    name: "ClipboardToolApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClipboardToolApp", targets: ["ClipboardToolApp"])
    ],
    targets: [
        .executableTarget(
            name: "ClipboardToolApp",
            path: "Sources/ClipboardToolApp",
            resources: [
                // For SwiftPM builds this is only used for packaging in `.build`.
                .process("../../Resources")
            ],
            linkerSettings: [
                // Link against the Go dylib we copy into Vendor/core
                .unsafeFlags([
                    "-L", "Vendor/core",
                    "-lclipboardtool",

                    // Make `swift run` work: the built executable lives under
                    // `.build/arm64-apple-macosx/debug/`, so Vendor/core is at:
                    // `@loader_path/../../../Vendor/core`
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@loader_path/../../../Vendor/core"
                ])
            ]
        )
    ]
)
