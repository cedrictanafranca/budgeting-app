import Foundation

/// Result of logging a transaction that came from outside the app (Shortcuts, Apple Pay automation).
public enum LogOutcome: Sendable {
    /// A new transaction was saved.
    case created(Transaction)
    /// The purchase was already logged; nothing was saved.
    case duplicate(existing: Transaction)

    public var transaction: Transaction {
        switch self {
        case .created(let transaction): return transaction
        case .duplicate(let existing): return existing
        }
    }

    public var isDuplicate: Bool {
        if case .duplicate = self { return true }
        return false
    }
}

/// Everything an external caller (the Log Expense App Intent) knows about a purchase.
/// Only `merchant` and `amount` are required; the store resolves account and category.
public struct ExternalExpenseRequest: Sendable {
    /// Raw merchant string as delivered by Wallet/Shortcuts (e.g. "SQ *BLUE BOTTLE #12").
    public var merchant: String
    /// Positive magnitude. Sign comes from `kind`.
    public var amount: Money
    public var kind: TransactionKind
    public var date: Date
    /// Wallet card display name; matched against `Account.cardIdentifier` / `Account.name`.
    public var cardIdentifier: String?
    /// Explicit category chosen in the shortcut. Wins over the categorizer when it exists.
    public var categoryID: UUID?
    public var note: String?
    public var source: TransactionSource
    /// Free-form raw data for debugging (card name, original merchant string…).
    public var paymentMetadata: String?

    public init(
        merchant: String,
        amount: Money,
        kind: TransactionKind = .expense,
        date: Date = Date(),
        cardIdentifier: String? = nil,
        categoryID: UUID? = nil,
        note: String? = nil,
        source: TransactionSource = .shortcut,
        paymentMetadata: String? = nil
    ) {
        self.merchant = merchant
        self.amount = amount
        self.kind = kind
        self.date = date
        self.cardIdentifier = cardIdentifier
        self.categoryID = categoryID
        self.note = note
        self.source = source
        self.paymentMetadata = paymentMetadata
    }
}

@MainActor
public extension BudgetStore {
    /// Logs a transaction from Shortcuts / Apple Pay. Resolves the account from the card name,
    /// suggests a category, and skips the save when `DuplicateDetector` finds the same purchase.
    /// Validation and persistence failures are thrown as `BudgetError`.
    func logExternal(_ request: ExternalExpenseRequest) throws -> LogOutcome {
        let merchant = CategorizationEngine.cleanDisplayName(request.merchant)
        guard !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw BudgetError.missingMerchant }
        let amount = request.amount.rounded
        guard amount.amount > 0 else { throw BudgetError.invalidAmount }

        let account = account(matchingCard: request.cardIdentifier) ?? defaultExpenseAccount

        let categoryID: UUID?
        switch request.kind {
        case .expense:
            categoryID = resolveCategory(for: merchant, explicit: request.categoryID).id
        case .income:
            // Refunds / income: the merchant rules describe spending, so only an explicit choice applies.
            categoryID = request.categoryID.flatMap { category(id: $0)?.id }
        case .transfer:
            categoryID = nil
        }

        let trimmedNote = request.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata = request.paymentMetadata ?? Self.defaultMetadata(rawMerchant: request.merchant, card: request.cardIdentifier)

        let candidate = Transaction(
            kind: request.kind,
            amount: amount,
            merchant: merchant,
            note: (trimmedNote?.isEmpty ?? true) ? nil : trimmedNote,
            date: request.date,
            categoryID: categoryID,
            accountID: account?.id,
            source: request.source,
            externalFingerprint: DuplicateDetector.fingerprint(merchant: merchant, amount: amount, date: request.date),
            paymentMetadata: metadata
        )

        if let existing = DuplicateDetector().existingDuplicate(of: candidate, in: transactions) {
            return .duplicate(existing: existing)
        }
        let saved = try add(candidate)
        return .created(saved)
    }

    /// Account whose `cardIdentifier` (preferred) or name matches the Wallet card name,
    /// case-insensitively, by equality first and then substring in either direction.
    /// Returns nil when `identifier` is nil/blank or nothing matches.
    func account(matchingCard identifier: String?) -> Account? {
        guard let needle = identifier?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !needle.isEmpty else { return nil }
        let candidates = activeAccounts

        func key(_ value: String?) -> String? {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !value.isEmpty else { return nil }
            return value
        }
        func matches(_ value: String?, exact: Bool) -> Bool {
            guard let value = key(value) else { return false }
            return exact ? value == needle : (needle.contains(value) || value.contains(needle))
        }

        return candidates.first { matches($0.cardIdentifier, exact: true) }
            ?? candidates.first { matches($0.cardIdentifier, exact: false) }
            ?? candidates.first { matches($0.name, exact: true) }
            ?? candidates.first { matches($0.name, exact: false) }
    }

    /// Category for a merchant: an existing explicit category wins, else the categorizer's suggestion, else nil.
    func resolveCategory(for merchant: String, explicit: UUID?) -> (id: UUID?, suggestion: CategorySuggestion?) {
        if let explicit, let category = category(id: explicit) {
            return (category.id, nil)
        }
        if let suggestion = categorizer.suggest(merchant: merchant), category(id: suggestion.categoryID) != nil {
            return (suggestion.categoryID, suggestion)
        }
        return (nil, nil)
    }

    private static func defaultMetadata(rawMerchant: String, card: String?) -> String? {
        var parts: [String] = []
        let raw = rawMerchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty { parts.append("merchant: \(raw)") }
        if let card = card?.trimmingCharacters(in: .whitespacesAndNewlines), !card.isEmpty { parts.append("card: \(card)") }
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }
}
