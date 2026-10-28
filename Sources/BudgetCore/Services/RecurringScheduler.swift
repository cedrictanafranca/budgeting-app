import Foundation

/// Materializes due recurring transactions exactly once per period.
public struct RecurringScheduler: Sendable {
    public var calendar: Calendar
    public init(calendar: Calendar = .current) { self.calendar = calendar }

    /// Period key for `date` under `rule.frequency`, e.g. "2026-10", "2026-W44", "2026-10-30".
    public func periodKey(for rule: RecurringRule, on date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .weekOfYear, .yearForWeekOfYear], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let weekYear = components.yearForWeekOfYear ?? year
        let week = components.weekOfYear ?? 0
        switch rule.frequency {
        case .daily: return String(format: "%04ld-%02ld-%02ld", year, month, day)
        case .weekly, .biweekly: return String(format: "%04ld-W%02ld", weekYear, week)
        case .monthly: return String(format: "%04ld-%02ld", year, month)
        case .yearly: return String(format: "%04ld", year)
        }
    }

    /// The date of the `index`-th occurrence (0 = `startDate`), computed from the start date so that
    /// month-end clamping never drifts (Jan 31 → Feb 28 → Mar 31, not Mar 28).
    public func occurrence(_ index: Int, for rule: RecurringRule) -> Date? {
        let step = max(rule.interval, 1) * index
        switch rule.frequency {
        case .daily: return calendar.date(byAdding: .day, value: step, to: rule.startDate)
        case .weekly: return calendar.date(byAdding: .day, value: step * 7, to: rule.startDate)
        case .biweekly: return calendar.date(byAdding: .day, value: step * 14, to: rule.startDate)
        case .monthly: return calendar.date(byAdding: .month, value: step, to: rule.startDate)
        case .yearly: return calendar.date(byAdding: .year, value: step, to: rule.startDate)
        }
    }

    /// Occurrence dates for `rule` between `rule.startDate` and `now` (inclusive) that have not been generated yet.
    /// Paused rules produce nothing; `endDate` (inclusive) caps the series.
    public func dueOccurrences(for rule: RecurringRule, now: Date = Date()) -> [Date] {
        guard !rule.isPaused else { return [] }
        let generated = Set(rule.generatedPeriodKeys)
        var seenKeys = Set<String>()
        var due: [Date] = []
        // Hard cap so a bad rule (start date far in the past, daily) can't spin forever.
        for index in 0..<20_000 {
            guard let date = occurrence(index, for: rule), date <= now else { break }
            if let end = rule.endDate, date > end { break }
            let key = periodKey(for: rule, on: date)
            guard !generated.contains(key), seenKeys.insert(key).inserted else { continue }
            due.append(date)
        }
        return due
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
