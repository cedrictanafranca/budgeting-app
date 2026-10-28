import Foundation

// CONTRACT FILE — signatures are frozen so UI / intents can build against them.

public struct CategorySummary: Identifiable, Hashable, Sendable {
    public var category: Category
    public var budgeted: Money?
    public var spent: Money
    /// budgeted - spent (nil when no budget). For `.savings`, this is target - funded.
    public var remaining: Money?
    /// 0…1+ fraction of budget used (nil when no budget).
    public var progress: Double?
    public var transactionCount: Int
    public var id: UUID { category.id }

    public init(category: Category, budgeted: Money?, spent: Money, remaining: Money?, progress: Double?, transactionCount: Int) {
        self.category = category
        self.budgeted = budgeted
        self.spent = spent
        self.remaining = remaining
        self.progress = progress
        self.transactionCount = transactionCount
    }
}

public struct PeriodSummary: Hashable, Sendable {
    public var period: BudgetPeriod
    public var interval: DateInterval
    public var daysLeft: Int
    public var budgeted: Money
    public var spent: Money
    public var remaining: Money
    public var categories: [CategorySummary]

    public init(period: BudgetPeriod, interval: DateInterval, daysLeft: Int, budgeted: Money, spent: Money, remaining: Money, categories: [CategorySummary]) {
        self.period = period
        self.interval = interval
        self.daysLeft = daysLeft
        self.budgeted = budgeted
        self.spent = spent
        self.remaining = remaining
        self.categories = categories
    }
}

public struct DailyTotal: Identifiable, Hashable, Sendable {
    public var day: Date
    public var total: Money
    public var id: Date { day }
    public init(day: Date, total: Money) { self.day = day; self.total = total }
}

public struct MonthlyTotal: Identifiable, Hashable, Sendable {
    public var month: Date
    public var spent: Money
    public var income: Money
    public var id: Date { month }
    public init(month: Date, spent: Money, income: Money) { self.month = month; self.spent = spent; self.income = income }
}

/// Pure budget math. Stateless; construct with the user's calendar settings.
public struct BudgetCalculator: Sendable {
    public var calendar: Calendar

    /// Fixed id of the synthetic "Uncategorized" category used by `spendingByCategory`.
    public static let uncategorizedID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// Synthetic category that groups expenses with no category in breakdowns.
    public static let uncategorizedCategory = Category(
        id: BudgetCalculator.uncategorizedID,
        name: "Uncategorized",
        emoji: "❔",
        colorHex: "#9CA3AF",
        period: .monthly,
        budget: nil,
        sortOrder: Int.max
    )

    /// Longest interval (in days) that `dailyTotals` will expand before clamping to the last 90 days.
    static let maxDailyIntervalDays = 400
    static let clampedDailyDays = 90

    public init(calendar: Calendar = .current, weekStartsOn: Int = 1) {
        var cal = calendar
        cal.firstWeekday = weekStartsOn
        self.calendar = cal
    }

    // MARK: Intervals

    /// Week/month containing `date`. For `.savings` returns the all-time interval (distantPast…distantFuture).
    public func interval(for period: BudgetPeriod, containing date: Date) -> DateInterval {
        switch period {
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 86_400)
        case .monthly:
            return calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: calendar.startOfDay(for: date), duration: 30 * 86_400)
        case .savings:
            return DateInterval(start: .distantPast, end: .distantFuture)
        }
    }

    /// Interval shifted by `offset` periods (negative = past). Used for month/week navigation.
    public func interval(for period: BudgetPeriod, containing date: Date, offset: Int) -> DateInterval {
        let base = interval(for: period, containing: date)
        guard period != .savings, offset != 0 else { return base }
        let component: Calendar.Component = period == .weekly ? .weekOfYear : .month
        guard let shifted = calendar.date(byAdding: component, value: offset, to: base.start) else { return base }
        return interval(for: period, containing: shifted)
    }

    /// Whole days remaining in the interval including today (Luna shows "4 days left").
    /// The interval end is exclusive, so on the last day of a month this returns 1.
    public func daysLeft(in interval: DateInterval, from date: Date = Date()) -> Int {
        let today = calendar.startOfDay(for: date)
        // Looking at a future period: the whole period is still ahead.
        let start = max(today, interval.start)
        let days = calendar.dateComponents([.day], from: start, to: interval.end).day ?? 0
        return max(days, 0)
    }

    // MARK: Summaries

    /// Budget overview for one period group (the Weekly / Monthly / Savings sections on Home).
    /// Only expenses count toward `spent`. Categories not in `period` and archived categories are ignored.
    /// `.savings` categories are funded cumulatively: spent = funded all-time, remaining = target - funded.
    public func summary(period: BudgetPeriod, categories: [Category], transactions: [Transaction], on date: Date = Date(), currency: String = Money.defaultCurrency) -> PeriodSummary {
        let interval = interval(for: period, containing: date)
        let relevant = categories
            .filter { $0.period == period && !$0.isArchived }
            .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }

        // Group expenses by category once instead of filtering per category.
        var grouped: [UUID: [Transaction]] = [:]
        for transaction in transactions where transaction.kind == .expense {
            guard let categoryID = transaction.categoryID else { continue }
            if period != .savings && !interval.contains(transaction.date) { continue }
            grouped[categoryID, default: []].append(transaction)
        }

        let summaries = relevant.map { category -> CategorySummary in
            let matching = grouped[category.id] ?? []
            let spent = Money.sum(matching.map(\.amount), currency: currency)
            return categorySummary(category: category, spent: spent, count: matching.count)
        }
        let budgeted = Money.sum(summaries.compactMap(\.budgeted), currency: currency)
        let spent = Money.sum(summaries.map(\.spent), currency: currency)
        let left = period == .savings ? 0 : daysLeft(in: interval, from: date)
        return PeriodSummary(period: period, interval: interval, daysLeft: left, budgeted: budgeted, spent: spent, remaining: budgeted - spent, categories: summaries)
    }

    private func categorySummary(category: Category, spent: Money, count: Int) -> CategorySummary {
        let remaining = category.budget.map { $0 - spent }
        let progress: Double? = category.budget.flatMap { $0.amount > 0 ? (spent.amount / $0.amount).doubleApprox : nil }
        return CategorySummary(category: category, budgeted: category.budget, spent: spent, remaining: remaining, progress: progress, transactionCount: count)
    }

    /// Total expenses within `interval` (all categories, including uncategorized).
    public func totalSpent(transactions: [Transaction], in interval: DateInterval, currency: String = Money.defaultCurrency) -> Money {
        Money.sum(transactions.filter { $0.kind == .expense && interval.contains($0.date) }.map(\.amount), currency: currency)
    }

    /// Total income within `interval`.
    public func totalIncome(transactions: [Transaction], in interval: DateInterval, currency: String = Money.defaultCurrency) -> Money {
        Money.sum(transactions.filter { $0.kind == .income && interval.contains($0.date) }.map(\.amount), currency: currency)
    }

    // MARK: Daily / monthly series

    /// One entry per calendar day in `interval` (zero-filled, ascending) — feeds the Transactions bar chart.
    /// Intervals longer than 400 days (savings / all-time) are clamped to the last 90 days ending at
    /// `interval.end` or today, whichever is earlier.
    public func dailyTotals(transactions: [Transaction], in interval: DateInterval, currency: String = Money.defaultCurrency) -> [DailyTotal] {
        dailyTotals(transactions: transactions, in: interval, currency: currency, now: Date())
    }

    /// Same as `dailyTotals(transactions:in:currency:)` with an explicit "today" (used by checks).
    public func dailyTotals(transactions: [Transaction], in interval: DateInterval, currency: String = Money.defaultCurrency, now: Date) -> [DailyTotal] {
        let days = daysToChart(in: interval, now: now)
        guard !days.isEmpty else { return [] }
        var byDay: [Date: Money] = [:]
        for transaction in transactions where transaction.kind == .expense && interval.contains(transaction.date) {
            byDay[calendar.startOfDay(for: transaction.date), default: .zero(currency)] += transaction.amount
        }
        return days.map { DailyTotal(day: $0, total: byDay[$0] ?? .zero(currency)) }
    }

    /// Start-of-day dates to chart for `interval`, ascending.
    func daysToChart(in interval: DateInterval, now: Date) -> [Date] {
        let spanDays = interval.duration / 86_400
        var first: Date
        var endExclusive: Date
        if spanDays > Double(Self.maxDailyIntervalDays) {
            // `interval.end` is exclusive, so a past interval's last day is the day before it.
            let lastMoment = min(interval.end.addingTimeInterval(-1), now)
            let lastDay = calendar.startOfDay(for: lastMoment)
            guard let start = calendar.date(byAdding: .day, value: -(Self.clampedDailyDays - 1), to: lastDay),
                  let end = calendar.date(byAdding: .day, value: 1, to: lastDay) else { return [] }
            first = start
            endExclusive = end
        } else {
            first = calendar.startOfDay(for: interval.start)
            endExclusive = interval.end
        }
        var days: [Date] = []
        var cursor = first
        while cursor < endExclusive {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    /// Spent and income per month for the last `months` months, oldest first, zero-filled — feeds Reports.
    /// The last entry is the month containing `date`.
    public func monthlyTotals(transactions: [Transaction], months: Int, endingAt date: Date = Date(), currency: String = Money.defaultCurrency) -> [MonthlyTotal] {
        guard months > 0, let endMonth = calendar.dateInterval(of: .month, for: date) else { return [] }
        var starts: [Date] = []
        for back in stride(from: months - 1, through: 0, by: -1) {
            guard let shifted = calendar.date(byAdding: .month, value: -back, to: endMonth.start),
                  let monthStart = calendar.dateInterval(of: .month, for: shifted)?.start else { continue }
            starts.append(monthStart)
        }
        var spent: [Date: Money] = [:]
        var income: [Date: Money] = [:]
        let wanted = Set(starts)
        for transaction in transactions where transaction.kind != .transfer {
            guard let monthStart = calendar.dateInterval(of: .month, for: transaction.date)?.start, wanted.contains(monthStart) else { continue }
            if transaction.kind == .expense {
                spent[monthStart, default: .zero(currency)] += transaction.amount
            } else {
                income[monthStart, default: .zero(currency)] += transaction.amount
            }
        }
        return starts.map { MonthlyTotal(month: $0, spent: spent[$0] ?? .zero(currency), income: income[$0] ?? .zero(currency)) }
    }

    /// Cumulative spend per day across the interval (Luna's "Monthly Spend vs Budget" line).
    /// Zero-filled and ascending; each entry is the running total through the end of that day.
    public func cumulativeDailySpend(transactions: [Transaction], in interval: DateInterval, currency: String = Money.defaultCurrency) -> [DailyTotal] {
        cumulativeDailySpend(transactions: transactions, in: interval, currency: currency, now: Date())
    }

    /// Same as `cumulativeDailySpend(transactions:in:currency:)` with an explicit "today" (used by checks).
    public func cumulativeDailySpend(transactions: [Transaction], in interval: DateInterval, currency: String = Money.defaultCurrency, now: Date) -> [DailyTotal] {
        var running = Money.zero(currency)
        return dailyTotals(transactions: transactions, in: interval, currency: currency, now: now).map { entry in
            running += entry.total
            return DailyTotal(day: entry.day, total: running)
        }
    }

    // MARK: Accounts

    /// Current balance: opening balance adjusted by all transactions on/after `openingDate`.
    /// Credit cards report the amount OWED: expenses increase it, transfers *into* the card (payments)
    /// and income (refunds) reduce it.
    /// Bank/cash: income adds, expenses and transfers out subtract, transfers in add.
    public func balance(for account: Account, transactions: [Transaction]) -> Money {
        var total = account.openingBalance
        let isLiability = account.type.isLiability
        for transaction in transactions where transaction.date >= account.openingDate {
            let amount = transaction.amount
            switch transaction.kind {
            case .income:
                guard transaction.accountID == account.id else { continue }
                total = isLiability ? total - amount : total + amount
            case .expense:
                guard transaction.accountID == account.id else { continue }
                total = isLiability ? total + amount : total - amount
            case .transfer:
                if transaction.accountID == account.id {
                    // Money leaving a bank account; a cash advance from a card increases what is owed.
                    total = isLiability ? total + amount : total - amount
                }
                if transaction.transferToAccountID == account.id {
                    // Money arriving: a payment reduces what is owed on a card, adds to a bank account.
                    total = isLiability ? total - amount : total + amount
                }
            }
        }
        return total
    }

    /// Most recent transaction date touching the account, for "Updated 3 days ago".
    public func lastActivity(for account: Account, transactions: [Transaction]) -> Date? {
        transactions.filter { $0.accountID == account.id || $0.transferToAccountID == account.id }.map(\.date).max()
    }

    // MARK: Breakdown

    /// Spending grouped by category for a date range, largest first (Reports / breakdown ring).
    /// Expenses without a category are grouped under a synthetic "Uncategorized" entry; expenses whose
    /// category no longer exists are skipped.
    public func spendingByCategory(transactions: [Transaction], categories: [Category], in interval: DateInterval, currency: String = Money.defaultCurrency) -> [CategorySummary] {
        let byID = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var grouped: [UUID: (category: Category, total: Money, count: Int)] = [:]
        for transaction in transactions where transaction.kind == .expense && interval.contains(transaction.date) {
            let category: Category
            if let id = transaction.categoryID {
                guard let found = byID[id] else { continue }
                category = found
            } else {
                category = Self.uncategorizedCategory
            }
            var entry = grouped[category.id] ?? (category, .zero(currency), 0)
            entry.total += transaction.amount
            entry.count += 1
            grouped[category.id] = entry
        }
        return grouped.values
            .map { categorySummary(category: $0.category, spent: $0.total, count: $0.count) }
            .sorted {
                if $0.spent != $1.spent { return $0.spent > $1.spent }
                return ($0.category.sortOrder, $0.category.name) < ($1.category.sortOrder, $1.category.name)
            }
    }
}

extension Decimal {
    var doubleApprox: Double { NSDecimalNumber(decimal: self).doubleValue }
}
