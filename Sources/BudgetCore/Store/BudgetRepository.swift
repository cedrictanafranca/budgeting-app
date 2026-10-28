import Foundation

public enum BudgetError: Error, LocalizedError, Equatable {
    case invalidAmount
    case missingMerchant
    case duplicate(existingID: UUID)
    case notFound
    case persistenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidAmount: return "Amount must be greater than zero."
        case .missingMerchant: return "Enter a merchant or item name."
        case .duplicate: return "This transaction was already logged."
        case .notFound: return "Item not found."
        case .persistenceFailed(let message): return "Couldn't save: \(message)"
        }
    }
}

/// Storage boundary. The SwiftData implementation lives in Packages/BudgetPersistence
/// (needs Xcode); `InMemoryBudgetRepository` is used for previews, tests and the macOS build.
/// Every method is write-through: the store updates memory only after the repository succeeds.
public protocol BudgetRepository: AnyObject {
    func load() throws -> BudgetSnapshot

    func upsert(transaction: Transaction) throws
    func deleteTransaction(id: UUID) throws

    func upsert(category: Category) throws
    func deleteCategory(id: UUID) throws

    func upsert(account: Account) throws
    func deleteAccount(id: UUID) throws

    func upsert(merchantRule: MerchantRule) throws
    func deleteMerchantRule(id: UUID) throws

    func upsert(recurringRule: RecurringRule) throws
    func deleteRecurringRule(id: UUID) throws

    func save(settings: BudgetSettings) throws

    /// Replace everything (used by restore / import).
    func replaceAll(with snapshot: BudgetSnapshot) throws
}

public final class InMemoryBudgetRepository: BudgetRepository {
    public private(set) var snapshot: BudgetSnapshot

    public init(snapshot: BudgetSnapshot = .empty) {
        self.snapshot = snapshot
    }

    public func load() throws -> BudgetSnapshot { snapshot }

    public func upsert(transaction: Transaction) throws {
        snapshot.transactions.upsert(transaction)
    }
    public func deleteTransaction(id: UUID) throws {
        snapshot.transactions.removeAll { $0.id == id }
    }
    public func upsert(category: Category) throws {
        snapshot.categories.upsert(category)
    }
    public func deleteCategory(id: UUID) throws {
        snapshot.categories.removeAll { $0.id == id }
    }
    public func upsert(account: Account) throws {
        snapshot.accounts.upsert(account)
    }
    public func deleteAccount(id: UUID) throws {
        snapshot.accounts.removeAll { $0.id == id }
    }
    public func upsert(merchantRule: MerchantRule) throws {
        snapshot.merchantRules.upsert(merchantRule)
    }
    public func deleteMerchantRule(id: UUID) throws {
        snapshot.merchantRules.removeAll { $0.id == id }
    }
    public func upsert(recurringRule: RecurringRule) throws {
        snapshot.recurringRules.upsert(recurringRule)
    }
    public func deleteRecurringRule(id: UUID) throws {
        snapshot.recurringRules.removeAll { $0.id == id }
    }
    public func save(settings: BudgetSettings) throws {
        snapshot.settings = settings
    }
    public func replaceAll(with snapshot: BudgetSnapshot) throws {
        self.snapshot = snapshot
    }
}

public extension Array where Element: Identifiable {
    /// Replace the element with the same id, or append.
    mutating func upsert(_ element: Element) {
        if let index = firstIndex(where: { $0.id == element.id }) {
            self[index] = element
        } else {
            append(element)
        }
    }

    subscript(id id: Element.ID) -> Element? {
        first { $0.id == id }
    }
}
