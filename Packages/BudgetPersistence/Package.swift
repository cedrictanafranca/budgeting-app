// swift-tools-version: 5.10
import PackageDescription

// SwiftData persistence. Builds ONLY inside Xcode (the @Model macro plugin is not in the
// Command Line Tools), which is why it is a separate package from the root BudgetKit.
let package = Package(
    name: "BudgetPersistence",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BudgetPersistence", targets: ["BudgetPersistence"]),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .target(name: "BudgetPersistence", dependencies: [.product(name: "BudgetCore", package: "BudgetKit")]),
    ]
)
