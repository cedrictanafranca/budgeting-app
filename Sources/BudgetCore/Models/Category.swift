import Foundation

/// Luna groups categories by the period their budget resets on.
/// `.savings` categories have a target that is funded over time instead of a resetting budget.
public enum BudgetPeriod: String, Codable, Sendable, CaseIterable, Identifiable {
    case weekly, monthly, savings
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .savings: return "Savings"
        }
    }
}

public struct Category: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    /// Single emoji shown inside the colored circle (Luna style), e.g. "☕️".
    public var emoji: String
    /// Hex color like "#5B3DF5" for the circle background.
    public var colorHex: String
    public var period: BudgetPeriod
    /// Budget per period, or savings target for `.savings`. nil = no limit set.
    public var budget: Money?
    public var sortOrder: Int
    public var isArchived: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        colorHex: String,
        period: BudgetPeriod = .monthly,
        budget: Money? = nil,
        sortOrder: Int = 0,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.period = period
        self.budget = budget
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }
}
