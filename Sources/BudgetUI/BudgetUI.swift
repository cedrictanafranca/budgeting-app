import SwiftUI
import BudgetCore

/// Root view the app target presents. Owns the tab bar and the add-transaction sheet.
/// Implemented by the UI agent; this placeholder keeps the package building.
public struct RootView: View {
    @Bindable var store: BudgetStore

    public init(store: BudgetStore) {
        self.store = store
    }

    public var body: some View {
        Text("RootView placeholder — \(store.transactions.count) transactions")
            .font(Theme.Fonts.body)
    }
}
