import SwiftUI
import os
import BudgetCore
import BudgetUI
import BudgetPersistence
// No `import BudgetIntents`: Sources/BudgetIntents is compiled directly into this app target
// (see project.yml) so Xcode's App Intents metadata extraction always sees LogExpenseIntent and
// BudgetShortcuts. `BudgetIntentsBootstrap` is therefore part of this module.

@main
struct BudgetingApp: App {
    @State private var store: BudgetStore
    @Environment(\.scenePhase) private var scenePhase

    private static let logger = Logger(subsystem: "com.cedrictanafranca.budgeting", category: "App")

    init() {
        // Also runs when the system launches the app in the background to perform Log Expense,
        // so everything the intent needs is set up here, before any scene exists.
        let repository: BudgetRepository
        do {
            let swiftData = try SwiftDataBudgetRepository()
            Self.logger.info("SwiftData store at \(swiftData.storeURL?.path ?? "memory", privacy: .public)")
            repository = swiftData
        } catch {
            // Keeps the app usable, but nothing will persist: surface it in Console.
            Self.logger.fault("SwiftData unavailable, using in-memory repository: \(String(describing: error), privacy: .public)")
            repository = InMemoryBudgetRepository()
        }

        let store = BudgetStore(repository: repository)
        store.seedDefaultsIfNeeded()
        BudgetIntentsBootstrap.register(store: store)
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .onChange(of: scenePhase) { _, phase in
                    // Pick up transactions the Log Expense intent saved while we were in the background.
                    if phase == .active { store.reload() }
                }
        }
    }
}
