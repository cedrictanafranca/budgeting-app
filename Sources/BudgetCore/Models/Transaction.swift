import Foundation

public enum TransactionKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case expense, income, transfer
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .transfer: return "Transfer"
        }
    }
}

/// Where a transaction came from. Used for dedupe, display and debugging.
public enum TransactionSource: String, Codable, Sendable, CaseIterable {
    case manual, applePay, shortcut, recurring, csvImport
}

public struct Transaction: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var kind: TransactionKind
    /// Always a positive magnitude. Sign is implied by `kind`.
    public var amount: Money
    /// Merchant or item name as the user sees it ("Starbucks").
    public var merchant: String
    public var note: String?
    public var date: Date
    /// nil for transfers or uncategorized expenses/income.
    public var categoryID: UUID?
    /// Account the money left (expense / transfer) or entered (income).
    public var accountID: UUID?
    /// Destination account for `.transfer` (e.g. credit card being paid off).
    public var transferToAccountID: UUID?
    public var source: TransactionSource
    /// Stable key for duplicate detection of externally-originated transactions
    /// (see `DuplicateDetector.fingerprint`). nil for manual entries.
    public var externalFingerprint: String?
    /// Raw payment metadata passed by Shortcuts (card name, last 4, etc.). Never required.
    public var paymentMetadata: String?
    public var recurringRuleID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        kind: TransactionKind = .expense,
        amount: Money,
        merchant: String,
        note: String? = nil,
        date: Date = Date(),
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        transferToAccountID: UUID? = nil,
        source: TransactionSource = .manual,
        externalFingerprint: String? = nil,
        paymentMetadata: String? = nil,
        recurringRuleID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.merchant = merchant
        self.note = note
        self.date = date
        self.categoryID = categoryID
        self.accountID = accountID
        self.transferToAccountID = transferToAccountID
        self.source = source
        self.externalFingerprint = externalFingerprint
        self.paymentMetadata = paymentMetadata
        self.recurringRuleID = recurringRuleID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Signed amount from the perspective of net worth: expenses negative, income positive, transfers zero.
    public var signedAmount: Money {
        switch kind {
        case .expense: return -amount
        case .income: return amount
        case .transfer: return Money.zero(amount.currencyCode)
        }
    }
}
