import Foundation
import SwiftData
import BudgetCore

/// `BudgetRepository` backed by SwiftData in the App Group container.
///
/// Threading: `BudgetStore` is `@MainActor` and is the only caller, so every method runs on the
/// main thread. The class is created on the main actor and uses the container's `mainContext`.
/// It is deliberately not annotated `@MainActor` itself because `BudgetRepository`'s requirements
/// are nonisolated and synchronous.
public final class SwiftDataBudgetRepository: BudgetRepository {
    public let container: ModelContainer
    private let context: ModelContext

    /// Where the store lives (nil when in memory). Useful for debugging / backups.
    public let storeURL: URL?

    public static var schema: Schema {
        Schema([
            TransactionRecord.self,
            CategoryRecord.self,
            AccountRecord.self,
            MerchantRuleRecord.self,
            RecurringRuleRecord.self,
            SettingsRecord.self,
        ])
    }

    /// - Parameter inMemory: true for previews/tests. Otherwise the store is created at
    ///   `<App Group>/Library/Application Support/Budget.store`, falling back to SwiftData's
    ///   default location when the App Group entitlement is unavailable.
    @MainActor
    public init(inMemory: Bool = false) throws {
        let schema = Self.schema
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            storeURL = nil
        } else if let url = BudgetPersistence.appGroupStoreURL() {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            storeURL = url
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            storeURL = configuration.url
        }
        container = try ModelContainer(for: schema, configurations: configuration)
        context = container.mainContext
        // Every write calls save() explicitly; autosave would only blur error reporting.
        context.autosaveEnabled = false
    }

    // MARK: - Load

    public func load() throws -> BudgetSnapshot {
        let transactions = try context.fetch(FetchDescriptor<TransactionRecord>()).map(\.domain)
        let categories = try context.fetch(FetchDescriptor<CategoryRecord>()).map(\.domain)
        let accounts = try context.fetch(FetchDescriptor<AccountRecord>()).map(\.domain)
        let merchantRules = try context.fetch(FetchDescriptor<MerchantRuleRecord>()).map(\.domain)
        let recurringRules = try context.fetch(FetchDescriptor<RecurringRuleRecord>()).map(\.domain)
        let settings = try fetchSettings()?.domain ?? BudgetSettings()
        return BudgetSnapshot(
            transactions: transactions,
            categories: categories,
            accounts: accounts,
            merchantRules: merchantRules,
            recurringRules: recurringRules,
            settings: settings
        )
    }

    // MARK: - Transactions

    public func upsert(transaction: BudgetCore.Transaction) throws {
        let id = transaction.id
        if let record = try first(#Predicate<TransactionRecord> { $0.id == id }) {
            record.update(from: transaction)
        } else {
            context.insert(TransactionRecord(transaction))
        }
        try saveContext()
    }

    public func deleteTransaction(id: UUID) throws {
        if let record = try first(#Predicate<TransactionRecord> { $0.id == id }) {
            context.delete(record)
            try saveContext()
        }
    }

    // MARK: - Categories

    public func upsert(category: BudgetCore.Category) throws {
        let id = category.id
        if let record = try first(#Predicate<CategoryRecord> { $0.id == id }) {
            record.update(from: category)
        } else {
            context.insert(CategoryRecord(category))
        }
        try saveContext()
    }

    public func deleteCategory(id: UUID) throws {
        if let record = try first(#Predicate<CategoryRecord> { $0.id == id }) {
            context.delete(record)
            try saveContext()
        }
    }

    // MARK: - Accounts

    public func upsert(account: BudgetCore.Account) throws {
        let id = account.id
        if let record = try first(#Predicate<AccountRecord> { $0.id == id }) {
            record.update(from: account)
        } else {
            context.insert(AccountRecord(account))
        }
        try saveContext()
    }

    public func deleteAccount(id: UUID) throws {
        if let record = try first(#Predicate<AccountRecord> { $0.id == id }) {
            context.delete(record)
            try saveContext()
        }
    }

    // MARK: - Merchant rules

    public func upsert(merchantRule: BudgetCore.MerchantRule) throws {
        let id = merchantRule.id
        if let record = try first(#Predicate<MerchantRuleRecord> { $0.id == id }) {
            record.update(from: merchantRule)
        } else {
            context.insert(MerchantRuleRecord(merchantRule))
        }
        try saveContext()
    }

    public func deleteMerchantRule(id: UUID) throws {
        if let record = try first(#Predicate<MerchantRuleRecord> { $0.id == id }) {
            context.delete(record)
            try saveContext()
        }
    }

    // MARK: - Recurring rules

    public func upsert(recurringRule: BudgetCore.RecurringRule) throws {
        let id = recurringRule.id
        if let record = try first(#Predicate<RecurringRuleRecord> { $0.id == id }) {
            record.update(from: recurringRule)
        } else {
            context.insert(RecurringRuleRecord(recurringRule))
        }
        try saveContext()
    }

    public func deleteRecurringRule(id: UUID) throws {
        if let record = try first(#Predicate<RecurringRuleRecord> { $0.id == id }) {
            context.delete(record)
            try saveContext()
        }
    }

    // MARK: - Settings

    public func save(settings: BudgetSettings) throws {
        if let record = try fetchSettings() {
            record.update(from: settings)
        } else {
            context.insert(SettingsRecord(settings))
        }
        try saveContext()
    }

    // MARK: - Replace all

    public func replaceAll(with snapshot: BudgetSnapshot) throws {
        // Delete row by row (not the batch `delete(model:)`) so the context's registered objects
        // and the unique constraints stay consistent before the re-insert below.
        try deleteAll(TransactionRecord.self)
        try deleteAll(CategoryRecord.self)
        try deleteAll(AccountRecord.self)
        try deleteAll(MerchantRuleRecord.self)
        try deleteAll(RecurringRuleRecord.self)
        try deleteAll(SettingsRecord.self)
        try saveContext()

        for value in snapshot.transactions { context.insert(TransactionRecord(value)) }
        for value in snapshot.categories { context.insert(CategoryRecord(value)) }
        for value in snapshot.accounts { context.insert(AccountRecord(value)) }
        for value in snapshot.merchantRules { context.insert(MerchantRuleRecord(value)) }
        for value in snapshot.recurringRules { context.insert(RecurringRuleRecord(value)) }
        context.insert(SettingsRecord(snapshot.settings))
        try saveContext()
    }

    // MARK: - Helpers

    private func first<Model: PersistentModel>(_ predicate: Predicate<Model>) throws -> Model? {
        var descriptor = FetchDescriptor<Model>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchSettings() throws -> SettingsRecord? {
        let key = BudgetPersistence.settingsKey
        return try first(#Predicate<SettingsRecord> { $0.key == key })
    }

    private func deleteAll<Model: PersistentModel>(_ type: Model.Type) throws {
        for record in try context.fetch(FetchDescriptor<Model>()) {
            context.delete(record)
        }
    }

    /// Saves, or rolls the context back so memory never diverges from disk after a failure.
    private func saveContext() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
