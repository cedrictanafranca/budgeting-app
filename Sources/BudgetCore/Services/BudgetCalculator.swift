import Foundation

// CONTRACT FILE — signatures are frozen so UI / intents can build against them.
// Bodies marked TODO(core-agent) are placeholders to be implemented with tests.

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

    public init(calendar: Calendar = .current, weekStartsOn: Int = 1) {
        var cal = calendar
        cal.firstWeekday = weekStartsOn
        self.calendar = cal
    }

    /// Week/month containing `date`. For `.savings` returns the all-time interval (distantPast…distantFuture).
    public func interval(for period: BudgetPeriod, containing date: Date) -> DateInterval {
        // TODO(core-agent): implement using calendar.dateInterval(of:for:)
        switch period {
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
        case .monthly:
            return calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 30 * 86_400)
        case .savings:
            return DateInterval(start: .distantPast, end: .distantFuture)
        }
    }

    /// Interval shifted by `offset` periods (negative = past). Used for month/week navigation.
    public func interval(for period: BudgetPeriod, containing date: Date, offset: Int) -> DateInterval {
        // TODO(core-agent)
        let base = interval(for: period, containing: date)
        let component: Calendar.Component = period == .weekly ? .weekOfYear : .month
        guard period != .savings, let shifted = calendar.date(byAdding: component, value: offset, to: base.start) else { return base }
        return interval(for: period, containing: shifted)
    }

    /// Whole days remaining in the interval including today (Luna shows "4 days left").
    public func daysLeft(in interval: DateInterval, from date: Date = Date()) -> Int {
        // TODO(core-agent)
        let start = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: interval.end).day ?? 0
        return max(days, 0)
    }

    /// Budget overview for one period group (the Weekly / Monthly / Savings sections on Home).
    /// Only expenses count toward `spent`. Categories not in `period` are ignored.
    public func summary(period: BudgetPeriod, categories: [Category], transactions: [Transaction], on date: Date = Date(), currency: String = Money.defaultCurrency) -> PeriodSummary {
        // TODO(core-agent): real implementation + tests (archived categories excluded, savings funded = all-time)
        let interval = interval(for: period, containing: date)
        let relevant = categories.filter { $0.period == period && !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
        let summaries = relevant.map { category -> CategorySummary in
            let matching = transactions.filter { $0.kind == .expense && $0.categoryID == category.id && interval.contains($0.date) }
            let spent = Money.sum(matching.map(\.amount), currency: currency)
            let remaining = category.budget.map { $0 - spent }
            let progress = category.budget.flatMap { $0.amount > 0 ? (spent.amount / $0.amount).doubleApprox : nil }
            return CategorySummary(category: category, budgeted: category.budget, spent: spent, remaining: remaining, progress: progress, transactionCount: matching.count)
        }
        let budgeted = Money.sum(summaries.compactMap(\.budgeted), currency: currency)
        let spent = Money.sum(summaries.map(\.spent), currency: currency)
        return PeriodSummary(period: period, interval: interval, daysLeft: daysLeft(in: interval, from: date), budgeted: budgeted, spent: spent, remaining: budgeted - spent, categories: summaries)
    }

    /// Total expenses within `interval` (all categories, including uncategorized).
    public func totalSpent(transactions: [Transaction], in interval: DateInterval, currency: String = Money.defaultCurrency) -> Money {
        Money.sum(transactions.filter { $0.kind == .expense && interval.contains($0.date) }.map(\.amount), currency: currency)
    }

    /// Total income within `interval`.
    public func totalIncome(transactions: [Transaction], in interval: DateInterval, currency: String = Money.defaultCurrency) -> Money {
        Money.sum(transactions.filter { $0.kind == .income && interval.contains($0.date) }.map(\.amount), currency: currency)
    }

    /// One entry per calendar day in `interval` (zero-filled) — feeds the Transactions bar chart.
    public func dailyTotals(transactions: [Transaction], in interval: DateInterval, currency: String = Money.defaultCurrency) -> [DailyTotal] {
        // TODO(core-agent): zero-fill every day; cap savings/all-time intervals sensibly
        var byDay: [Date: Money] = [:]
        for transaction in transactions where transaction.kind == .expense && interval.contains(transaction.date) {
            let day = calendar.startOfDay(for: transaction.date)
            byDay[day, default: .zero(currency)] += transaction.amount
        }
        return byDay.keys.sorted().map { DailyTotal(day: $0, total: byDay[$0]!) }
    }

    /// Spent and income per month for the last `months` months, oldest first — feeds Reports.
    public func monthlyTotals(transactions: [Transaction], months: Int, endingAt date: Date = Date(), currency: String = Money.defaultCurrency) -> [MonthlyTotal] {
        // TODO(core-agent)
        return []
    }

    /// Cumulative spend per day across the interval (Luna's "Monthly Spend vs Budget" line).
    public func cumulativeDailySpend(transactions: [Transaction], in interval: DateInterval, currency: String = Money.defaultCurrency) -> [DailyTotal] {
        // TODO(core-agent)
        return []
    }

    /// Current balance: opening balance adjusted by all transactions after `openingDate`.
    /// Credit cards: expenses increase the balance owed, transfers *into* the card reduce it.
    /// Bank/cash: income adds, expenses and transfers out subtract, transfers in add.
    public func balance(for account: Account, transactions: [Transaction]) -> Money {
        // TODO(core-agent): implement + tests for credit card payment as transfer (no double counting)
        return account.openingBalance
    }

    /// Most recent transaction date touching the account, for "Updated 3 days ago".
    public func lastActivity(for account: Account, transactions: [Transaction]) -> Date? {
        transactions.filter { $0.accountID == account.id || $0.transferToAccountID == account.id }.map(\.date).max()
    }

    /// Spending grouped by category for a date range, largest first (Reports / breakdown ring).
    public func spendingByCategory(transactions: [Transaction], categories: [Category], in interval: DateInterval, currency: String = Money.defaultCurrency) -> [CategorySummary] {
        // TODO(core-agent)
        return []
    }
}

extension Decimal {
    var doubleApprox: Double { NSDecimalNumber(decimal: self).doubleValue }
}
