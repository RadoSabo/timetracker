// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Timetracker",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "Timetracker",
            path: "Sources/Timetracker",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("FoundationModels"),
                .linkedFramework("EventKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "TimetrackerTests",
            dependencies: ["Timetracker"],
            path: "Tests/TimetrackerTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
