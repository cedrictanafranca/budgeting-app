# Budget

A native iOS budgeting app inspired by Luna, with Apple Pay purchases logged automatically through a Shortcuts automation and an App Intent.

- **Architecture, data model and the Shortcuts design:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Install on iPhone + connect Apple Pay:** [docs/SHORTCUTS_SETUP.md](docs/SHORTCUTS_SETUP.md)
- **Design references:** `docs/references/luna/`

## Quick start

```bash
swift build                   # domain, UI and intents compile on macOS with just the Command Line Tools
swift run BudgetCoreChecks    # unit checks
brew install xcodegen && xcodegen generate && open Budgeting.xcodeproj   # iOS app (needs Xcode)
```

## Layout

| Path | What |
|---|---|
| `Sources/BudgetCore` | `Money`, models, `BudgetStore`, repository protocol, pure services (budget math, categorization, duplicates, recurring, CSV) |
| `Sources/BudgetUI` | SwiftUI screens and theme tokens |
| `Sources/BudgetIntents` | `LogExpenseIntent`, entities, App Shortcuts |
| `Packages/BudgetPersistence` | SwiftData models and repository (App Group container) |
| `App/Budgeting` | App entry point, assets, privacy manifest |
| `Checks/BudgetCoreChecks` | Unit checks (`swift run BudgetCoreChecks`) |
