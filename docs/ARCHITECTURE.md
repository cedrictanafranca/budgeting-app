# Budget — Architecture

Native iOS budgeting app inspired by Luna. Personal use, local-first, Apple Pay → Shortcuts → App Intent automation.

## 1. Stack

| Layer | Choice | Why |
|---|---|---|
| UI | SwiftUI, iOS 17+ | Native sheets, animations, Swift Charts, widgets share views |
| State | `@Observable` `BudgetStore` (main actor) | One source of truth for app, intents and widgets; SwiftUI observation for free |
| Persistence | SwiftData in an **App Group** container | Shared by app, widgets, intents; CloudKit sync is a one-line opt-in later |
| Money | `Money` (`Decimal` + currency code) | No floating point; banker's rounding at the edges only |
| Automation | App Intents (`LogExpenseIntent`) + `AppShortcutsProvider` | Runs in-process from the Shortcuts automation without opening the app |
| Charts | Swift Charts | Interactive, native, matches Luna's look |
| Project | XcodeGen `project.yml` → `Budgeting.xcodeproj` | Reproducible project, no pbxproj merge pain |

## 2. Module layout

```
Package.swift                 BudgetKit — builds with Command Line Tools only (no Xcode needed)
├─ Sources/BudgetCore         Domain: Money, models, BudgetStore, repository protocol, pure services
├─ Sources/BudgetUI           SwiftUI screens + Theme tokens. Depends on BudgetCore only.
├─ Sources/BudgetIntents      LogExpenseIntent, AppShortcuts. Depends on BudgetCore only.
├─ Sources/CheckKit           Tiny test harness (XCTest is Xcode-only)
└─ Checks/BudgetCoreChecks    `swift run BudgetCoreChecks` — unit checks for BudgetCore
Packages/BudgetPersistence    SwiftData @Model classes + SwiftDataBudgetRepository (needs Xcode)
App/Budgeting                 @main app: wires store ← repository, registers intent dependencies
project.yml                   XcodeGen spec (app target, App Group entitlement)
docs/references/luna          Reference screenshots from the Figma board
```

Dependency rule: `BudgetUI` and `BudgetIntents` never import SwiftData. They talk to `BudgetStore`, which talks to a `BudgetRepository`. `InMemoryBudgetRepository` powers previews, checks and the macOS build; `SwiftDataBudgetRepository` powers the real app. This split is what lets most of the codebase compile and be checked on a Mac without Xcode, and it keeps widgets/intents from needing the UI.

## 3. Data model (BudgetCore/Models)

All domain types are plain `struct`s (`Codable`, `Sendable`, `Identifiable` by `UUID`). SwiftData `@Model` classes in BudgetPersistence mirror them 1:1 and convert at the repository boundary.

| Type | Key fields | Notes |
|---|---|---|
| `Transaction` | `kind` (expense/income/transfer), `amount: Money` (always positive), `merchant`, `date`, `categoryID?`, `accountID?`, `transferToAccountID?`, `source`, `externalFingerprint?`, `paymentMetadata?`, `recurringRuleID?` | Sign comes from `kind`. Credit-card payments are `.transfer` chequing → card, so they never count as spending. |
| `Category` | `name`, `emoji`, `colorHex`, `period` (weekly/monthly/savings), `budget: Money?`, `sortOrder`, `isArchived` | Luna's Home groups by `period`. Savings categories have a target that is funded cumulatively. |
| `Account` | `type` (chequing/savings/creditCard/cash), `openingBalance`, `openingDate`, `cardIdentifier?`, `isDefaultForExpenses` | Balance is derived (`BudgetCalculator.balance`). `cardIdentifier` maps a Wallet card name from Shortcuts to the account. |
| `MerchantRule` | `pattern` (normalized), `categoryID`, `displayName?`, `isUserDefined`, `hitCount` | User rules always beat built-in rules. Store learns a rule every time you categorize a merchant. |
| `RecurringRule` | template fields + `frequency`, `interval`, `startDate`, `endDate?`, `isPaused`, `generatedPeriodKeys` | A period key ("2026-10") is recorded when materialized → never logged twice. |
| `BudgetSettings` | `currencyCode` (CAD), `weekStartsOn`, `monthlyIncomeTarget?`, `userName` | |
| `BudgetSnapshot` | all of the above | Unit of load/backup/restore. |

Derived values are never stored: budget left, progress, account balances, daily totals and reports are computed by `BudgetCalculator` from transactions, so edits and deletes are always consistent.

## 4. Services (pure, testable)

- `BudgetCalculator` — period intervals, `PeriodSummary` (budgeted/spent/remaining per category), daily & monthly totals, cumulative spend, account balances.
- `CategorizationEngine` — `normalize()` merchant strings, `suggest(merchant:)` with precedence user rule → built-in rule → history → fallback ("Other"); `merchantSuggestions()` for autocomplete. No network, no ML; a classifier can be inserted as a later step without changing callers.
- `DuplicateDetector` — fingerprint (merchant + amount + 5-min bucket) and fuzzy match (same merchant+amount within 10 min).
- `RecurringScheduler` — due occurrences + period keys.
- `CSVCodec` / `BackupCodec` — export/import and JSON backup/restore.
- `DefaultData` — seeded categories (Luna's set), accounts, sample data for previews.

## 5. Apple Pay → Shortcuts → App Intent

**What Apple provides.** The Shortcuts app has a *Wallet* automation trigger ("When I tap a card / Transaction"). When it fires, the automation receives a **Transaction** object exposing: `Merchant`, `Amount`, `Card` (display name), `Date`, `Name`, `Category` (Apple's merchant category when available) and the raw text. There is **no** public API for an app to read Wallet/Apple Pay transactions directly (`PKPaymentPass` transactions are only visible to the card issuer's app). So the only supported path is exactly the one you already use: a Shortcuts automation that hands the data to our app.

**Flow.**
1. Apple Pay purchase completes → Wallet transaction automation runs (set to *Run Immediately*, no confirmation).
2. The automation calls our **Log Expense** action (`LogExpenseIntent`), passing `Merchant`, `Amount`, `Card`, `Date` from the trigger's Transaction variable.
3. `LogExpenseIntent.perform()` runs **in the app's process in the background** (no UI, `openAppWhenRun = false`):
   - parses the amount into `Money` (CAD unless the automation passes a currency),
   - maps `Card` → `Account` via `cardIdentifier` substring match, else the default expense account,
   - asks `CategorizationEngine` for a category (explicit parameter wins),
   - computes an `externalFingerprint` and asks `DuplicateDetector`; a duplicate returns a "already logged" result instead of a second row,
   - saves through `BudgetStore` → SwiftData in the App Group container,
   - returns a dialog ("Logged CA$6.45 at Starbucks → Coffee shops") and a `TransactionEntity` so follow-up actions (e.g. a notification) can use it.
4. The dashboard observes the store; widgets are reloaded via `WidgetCenter` after the save.
5. Review/correct in the app: the transaction shows a small "Apple Pay" source badge; changing its category creates a user `MerchantRule` so the next purchase at that merchant is right.

**Limitations and fallbacks.**
- The Wallet trigger only fires for Apple Pay (not physical card taps). Fallback: a manual *Log Expense* shortcut (same intent, prompts for merchant/amount) and the in-app quick add.
- `Merchant` strings are raw ("SQ *BLUE BOTTLE"); `cleanDisplayName()` tidies them and user rules can rename.
- Refunds arrive as positive amounts with no sign; the intent accepts a `kind` parameter so an automation can pass *Income* for refunds if desired.
- If the save fails (e.g. container unavailable) the intent throws a user-visible error; Shortcuts shows it, and the manual shortcut can be re-run. Nothing is silently dropped.
- Automations require the trigger device be unlocked recently; nothing we can change.

Setup steps live in `docs/SHORTCUTS_SETUP.md`.

## 6. Build & verify without Xcode

```bash
swift build                    # compiles BudgetCore, BudgetUI, BudgetIntents on macOS
swift run BudgetCoreChecks     # unit checks
xcodegen generate              # produces Budgeting.xcodeproj (needs `brew install xcodegen`)
```

Running on an iPhone requires Xcode (App Store) + signing in with your Apple ID under *Signing & Capabilities*. The App Group `group.com.cedrictanafranca.budgeting` must also be enabled there (Xcode registers it automatically with a personal team).

## 7. Phases

1. **Foundation (this PR):** models, store, services, dashboard, add-transaction flow, transactions list, accounts, LogExpenseIntent, Shortcuts guide.
2. Budget editing, income, search/filter, reports, account balances.
3. Apple Pay workflow end-to-end on device, categorization rules UI, duplicate handling UX.
4. Luna polish from screenshots, animations, widgets, recurring transactions, dark mode QA.
5. iCloud (CloudKit) sync, smarter categorization, more shortcuts, backup improvements.
