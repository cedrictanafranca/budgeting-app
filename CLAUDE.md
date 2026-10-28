# Budget (iOS) — agent notes

Read docs/ARCHITECTURE.md first. Reference screenshots: docs/references/luna/*.png (Luna app). Match them.

## Build / verify (no Xcode on this Mac — only Command Line Tools)
- `swift build --scratch-path .build-<yourname>` — compiles BudgetCore, BudgetUI, BudgetIntents for macOS. Must stay green.
- `swift run --scratch-path .build-<yourname> BudgetCoreChecks` — unit checks (CheckKit; XCTest is unavailable).
- `Packages/BudgetPersistence` and `App/` only compile in Xcode. Write them carefully; they are not verified here.
- iOS-only SwiftUI APIs must be wrapped in `#if os(iOS)` so the macOS build stays green. Prefer cross-platform APIs.
- Swift language mode 5 (tools 5.10). Keep `BudgetStore` main-actor; services are pure structs.

## Rules
- Money is `Money` (Decimal). Never Double for amounts.
- UI and intents never import SwiftData. Go through `BudgetStore`.
- Theme tokens live in Sources/BudgetUI/Theme/Theme.swift — no ad-hoc colors.
- Contract signatures in Sources/BudgetCore/Services are frozen; add, don't rename.
- Do not edit files outside your assigned area; do not run git commands unless asked.
