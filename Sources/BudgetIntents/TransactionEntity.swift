import AppIntents
import BudgetCore
import Foundation

/// A logged transaction, returned by Log Expense so later shortcut actions
/// (e.g. Show Notification) can use its merchant, amount and category.
public struct TransactionEntity: AppEntity, Identifiable {
    public let id: UUID

    @Property(title: "Merchant")
    public var merchant: String

    @Property(title: "Amount")
    public var amount: String

    @Property(title: "Category")
    public var categoryName: String

    @Property(title: "Date")
    public var date: Date

    public init(id: UUID, merchant: String, amount: String, categoryName: String, date: Date) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.categoryName = categoryName
        self.date = date
    }

    public init(_ transaction: BudgetCore.Transaction, categoryName: String?) {
        self.init(
            id: transaction.id,
            merchant: transaction.merchant,
            amount: transaction.amount.formatted(),
            categoryName: categoryName ?? "Uncategorized",
            date: transaction.date
        )
    }

    @MainActor
    public init(_ transaction: BudgetCore.Transaction, store: BudgetStore) {
        self.init(transaction, categoryName: store.category(id: transaction.categoryID)?.name)
    }

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Transaction"
    public static let defaultQuery = TransactionQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(amount) at \(merchant)", subtitle: "\(categoryName)")
    }
}

/// Minimal lookup: by id, and the most recent transactions as suggestions.
public struct TransactionQuery: EntityQuery {
    @Dependency private var store: BudgetStore

    public init() {}

    @MainActor
    public func entities(for identifiers: [TransactionEntity.ID]) async throws -> [TransactionEntity] {
        let wanted = Set(identifiers)
        return store.transactions
            .filter { wanted.contains($0.id) }
            .map { TransactionEntity($0, store: store) }
    }

    @MainActor
    public func suggestedEntities() async throws -> [TransactionEntity] {
        store.transactions.prefix(10).map { TransactionEntity($0, store: store) }
    }
}
