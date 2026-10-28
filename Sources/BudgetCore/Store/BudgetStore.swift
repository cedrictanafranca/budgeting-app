import Foundation
import Observation

/// Single source of truth for the UI, intents and widgets. Owns an in-memory `BudgetSnapshot`
/// and writes through to a `BudgetRepository`. Main-actor bound so SwiftUI observation is safe.
///
/// Derived numbers (budgets left, spending per day, category suggestions) come from the
/// pure services in `Services/` so they stay unit-testable without a store.
@MainActor
@Observable
public final class BudgetStore {
    public private(set) var transactions: [Transaction] = []
    public private(set) var categories: [Category] = []
    public private(set) var accounts: [Account] = []
    public private(set) var merchantRules: [MerchantRule] = []
    public private(set) var recurringRules: [RecurringRule] = []
    public private(set) var settings = BudgetSettings()
    public private(set) var lastError: BudgetError?

    private let repository: BudgetRepository
    public let calendar: Calendar

    public init(repository: BudgetRepository, calendar: Calendar = .current) {
        self.repository = repository
        self.calendar = calendar
        reload()
    }

    public var snapshot: BudgetSnapshot {
        BudgetSnapshot(
            transactions: transactions,
            categories: categories,
            accounts: accounts,
            merchantRules: merchantRules,
            recurringRules: recurringRules,
            settings: settings
        )
    }

    public func reload() {
        do {
            apply(try repository.load())
        } catch {
            lastError = .persistenceFailed(error.localizedDescription)
        }
    }

    private func apply(_ snapshot: BudgetSnapshot) {
        transactions = snapshot.transactions.sorted { $0.date > $1.date }
        categories = snapshot.categories.sorted { $0.sortOrder < $1.sortOrder }
        accounts = snapshot.accounts.sorted { $0.sortOrder < $1.sortOrder }
        merchantRules = snapshot.merchantRules
        recurringRules = snapshot.recurringRules
        settings = snapshot.settings
    }

    /// Seeds default categories/accounts/rules on first launch. Safe to call repeatedly.
    public func seedDefaultsIfNeeded() {
        guard categories.isEmpty else { return }
        let seededCategories = DefaultData.categories()
        for category in seededCategories { try? repository.upsert(category: category) }
        for account in DefaultData.accounts() { try? repository.upsert(account: account) }
        for rule in CategorizationEngine.builtInRules(categories: seededCategories) {
            try? repository.upsert(merchantRule: rule)
        }
        reload()
    }

    // MARK: - Transactions

    public var activeCategories: [Category] { categories.filter { !$0.isArchived } }
    public var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }
    public var defaultExpenseAccount: Account? {
        activeAccounts.first { $0.isDefaultForExpenses } ?? activeAccounts.first
    }

    @discardableResult
    public func add(_ transaction: Transaction) throws -> Transaction {
        try validate(transaction)
        var saved = transaction
        saved.updatedAt = Date()
        try perform { try repository.upsert(transaction: saved) }
        transactions.upsert(saved)
        transactions.sort { $0.date > $1.date }
        learnCategory(from: saved)
        return saved
    }

    public func update(_ transaction: Transaction) throws {
        try validate(transaction)
        var saved = transaction
        saved.updatedAt = Date()
        try perform { try repository.upsert(transaction: saved) }
        transactions.upsert(saved)
        transactions.sort { $0.date > $1.date }
        learnCategory(from: saved)
    }

    public func deleteTransaction(id: UUID) throws {
        try perform { try repository.deleteTransaction(id: id) }
        transactions.removeAll { $0.id == id }
    }

    private func validate(_ transaction: Transaction) throws {
        guard transaction.amount.amount > 0 else { throw BudgetError.invalidAmount }
        guard !transaction.merchant.trimmingCharacters(in: .whitespaces).isEmpty else { throw BudgetError.missingMerchant }
    }

    /// Remember the user's category choice for this merchant so future suggestions match.
    private func learnCategory(from transaction: Transaction) {
        guard transaction.kind == .expense, let categoryID = transaction.categoryID else { return }
        let pattern = CategorizationEngine.normalize(transaction.merchant)
        guard !pattern.isEmpty else { return }
        if var existing = merchantRules.first(where: { $0.pattern == pattern && $0.isUserDefined }) {
            existing.categoryID = categoryID
            existing.hitCount += 1
            existing.lastUsed = Date()
            try? repository.upsert(merchantRule: existing)
            merchantRules.upsert(existing)
        } else {
            let rule = MerchantRule(pattern: pattern, categoryID: categoryID, displayName: transaction.merchant, isUserDefined: true, hitCount: 1, lastUsed: Date())
            try? repository.upsert(merchantRule: rule)
            merchantRules.upsert(rule)
        }
    }

    // MARK: - Categories

    public func save(_ category: Category) throws {
        try perform { try repository.upsert(category: category) }
        categories.upsert(category)
        categories.sort { $0.sortOrder < $1.sortOrder }
    }

    public func deleteCategory(id: UUID) throws {
        try perform { try repository.deleteCategory(id: id) }
        categories.removeAll { $0.id == id }
        // Orphan transactions keep their history but lose the category.
        for var transaction in transactions where transaction.categoryID == id {
            transaction.categoryID = nil
            try? repository.upsert(transaction: transaction)
            transactions.upsert(transaction)
        }
    }

    // MARK: - Accounts

    public func save(_ account: Account) throws {
        try perform { try repository.upsert(account: account) }
        accounts.upsert(account)
        accounts.sort { $0.sortOrder < $1.sortOrder }
    }

    public func deleteAccount(id: UUID) throws {
        try perform { try repository.deleteAccount(id: id) }
        accounts.removeAll { $0.id == id }
    }

    // MARK: - Merchant rules

    public func save(_ rule: MerchantRule) throws {
        try perform { try repository.upsert(merchantRule: rule) }
        merchantRules.upsert(rule)
    }

    public func deleteMerchantRule(id: UUID) throws {
        try perform { try repository.deleteMerchantRule(id: id) }
        merchantRules.removeAll { $0.id == id }
    }

    // MARK: - Recurring rules

    public func save(_ rule: RecurringRule) throws {
        try perform { try repository.upsert(recurringRule: rule) }
        recurringRules.upsert(rule)
    }

    public func deleteRecurringRule(id: UUID) throws {
        try perform { try repository.deleteRecurringRule(id: id) }
        recurringRules.removeAll { $0.id == id }
    }

    // MARK: - Settings

    public func save(_ settings: BudgetSettings) throws {
        try perform { try repository.save(settings: settings) }
        self.settings = settings
    }

    public func restore(from snapshot: BudgetSnapshot) throws {
        try perform { try repository.replaceAll(with: snapshot) }
        apply(snapshot)
    }

    // MARK: - Helpers

    private func perform(_ work: () throws -> Void) throws {
        do {
            try work()
            lastError = nil
        } catch let error as BudgetError {
            lastError = error
            throw error
        } catch {
            let wrapped = BudgetError.persistenceFailed(error.localizedDescription)
            lastError = wrapped
            throw wrapped
        }
    }

    public func category(id: UUID?) -> Category? {
        guard let id else { return nil }
        return categories[id: id]
    }

    public func account(id: UUID?) -> Account? {
        guard let id else { return nil }
        return accounts[id: id]
    }

    public var calculator: BudgetCalculator {
        BudgetCalculator(calendar: calendar, weekStartsOn: settings.weekStartsOn)
    }

    public var categorizer: CategorizationEngine {
        CategorizationEngine(rules: merchantRules, categories: categories, history: transactions)
    }
}

public extension BudgetStore {
    /// In-memory store pre-filled with defaults and sample data for previews and tests.
    static func preview(sample: Bool = true) -> BudgetStore {
        let repository = InMemoryBudgetRepository()
        let store = BudgetStore(repository: repository)
        store.seedDefaultsIfNeeded()
        if sample {
            for transaction in DefaultData.sampleTransactions(categories: store.categories, accounts: store.accounts) {
                try? store.add(transaction)
            }
        }
        return store
    }
}
