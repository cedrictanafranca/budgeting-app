import AppIntents
import BudgetCore

/// Call once at launch (in `App.init`, before any scene) so intents and entity queries
/// can resolve `@Dependency var store: BudgetStore`. The system launches the app process
/// in the background to run Log Expense, which runs `App.init` first.
public enum BudgetIntentsBootstrap {
    @MainActor
    public static func register(store: BudgetStore) {
        AppDependencyManager.shared.add(dependency: store)
    }
}
