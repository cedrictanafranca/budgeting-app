// swift-tools-version: 5.10
import PackageDescription

// Root package: everything that can be compiled and checked with the Command Line Tools on
// macOS (no Xcode required). SwiftData persistence lives in Packages/BudgetPersistence because
// the @Model macro plugin only ships with Xcode. XCTest/swift-testing are also Xcode-only, so
// unit checks run as an executable: `swift run BudgetCoreChecks`.
let package = Package(
    name: "BudgetKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BudgetCore", targets: ["BudgetCore"]),
        .library(name: "BudgetUI", targets: ["BudgetUI"]),
        .library(name: "BudgetIntents", targets: ["BudgetIntents"]),
    ],
    targets: [
        .target(name: "BudgetCore"),
        .target(name: "BudgetUI", dependencies: ["BudgetCore"]),
        .target(name: "BudgetIntents", dependencies: ["BudgetCore"]),
        .target(name: "CheckKit"),
        .executableTarget(name: "BudgetCoreChecks", dependencies: ["BudgetCore", "CheckKit"], path: "Checks/BudgetCoreChecks"),
    ]
)
