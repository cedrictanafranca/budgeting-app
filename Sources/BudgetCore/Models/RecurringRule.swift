import Foundation

public enum RecurrenceFrequency: String, Codable, Sendable, CaseIterable, Identifiable {
    case daily, weekly, biweekly, monthly, yearly
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// Template for a recurring transaction (rent, subscriptions). The scheduler materializes
/// one `Transaction` per period and records the period key in `generatedPeriodKeys`
/// so a period is never recorded twice.
public struct RecurringRule: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var merchant: String
    public var amount: Money
    public var kind: TransactionKind
    public var categoryID: UUID?
    public var accountID: UUID?
    public var note: String?
    public var frequency: RecurrenceFrequency
    /// Every N units of `frequency` (1 = every period).
    public var interval: Int
    public var startDate: Date
    public var endDate: Date?
    public var isPaused: Bool
    /// Period keys already materialized, e.g. "2026-10" for monthly, "2026-W44" for weekly.
    public var generatedPeriodKeys: [String]

    public init(
        id: UUID = UUID(),
        merchant: String,
        amount: Money,
        kind: TransactionKind = .expense,
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        note: String? = nil,
        frequency: RecurrenceFrequency = .monthly,
        interval: Int = 1,
        startDate: Date = Date(),
        endDate: Date? = nil,
        isPaused: Bool = false,
        generatedPeriodKeys: [String] = []
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.kind = kind
        self.categoryID = categoryID
        self.accountID = accountID
        self.note = note
        self.frequency = frequency
        self.interval = interval
        self.startDate = startDate
        self.endDate = endDate
        self.isPaused = isPaused
        self.generatedPeriodKeys = generatedPeriodKeys
    }
}
