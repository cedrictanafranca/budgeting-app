import AppIntents

/// App Shortcuts surfaced in the Shortcuts app, Spotlight and Siri without any setup.
/// Only one `AppShortcutsProvider` may exist per app.
public struct BudgetShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log expense in \(.applicationName)",
                "Add expense to \(.applicationName)",
            ],
            shortTitle: "Log Expense",
            systemImageName: "plus.circle"
        )
    }
}
