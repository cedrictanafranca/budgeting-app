import Foundation

/// Materializes due recurring transactions exactly once per period.
public struct RecurringScheduler: Sendable {
    public var calendar: Calendar
    public init(calendar: Calendar = .current) { self.calendar = calendar }

    /// Period key for `date` under `rule.frequency`, e.g. "2026-10", "2026-W44", "2026-10-30".
    public func periodKey(for rule: RecurringRule, on date: Date) -> String {
        // TODO(core-agent)
        let components = calendar.dateComponents([.year, .month, .day, .weekOfYear, .yearForWeekOfYear], from: date)
        switch rule.frequency {
        case .daily: return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        case .weekly, .biweekly: return String(format: "%04d-W%02d", components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0)
        case .monthly: return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
        case .yearly: return String(format: "%04d", components.year ?? 0)
        }
    }

    /// Occurrence dates for `rule` between `rule.startDate` and `now` (inclusive) that have not been generated yet.
    public func dueOccurrences(for rule: RecurringRule, now: Date = Date()) -> [Date] {
        // TODO(core-agent): implement with interval/endDate/isPaused + tests
        return []
    }

    /// Build the transaction for one occurrence (does not persist).
    public func transaction(for rule: RecurringRule, on date: Date) -> Transaction {
        Transaction(
            kind: rule.kind,
            amount: rule.amount,
            merchant: rule.merchant,
            note: rule.note,
            date: date,
            categoryID: rule.categoryID,
            accountID: rule.accountID,
            source: .recurring,
            externalFingerprint: "recurring|\(rule.id.uuidString)|\(periodKey(for: rule, on: date))",
            recurringRuleID: rule.id
        )
    }
}
