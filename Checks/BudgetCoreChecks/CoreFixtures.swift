import Foundation
import BudgetCore

/// Foundation exposes an Objective-C `Category`; pin the domain type.
typealias Category = BudgetCore.Category

/// Shared helpers for the service checks. Everything is pinned to a UTC Gregorian calendar so results never
/// depend on the machine's time zone.
enum CoreFixtures {
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func calculator(weekStartsOn: Int = 1) -> BudgetCalculator {
        BudgetCalculator(calendar: utc, weekStartsOn: weekStartsOn)
    }

    static func expense(_ amount: Decimal, _ merchant: String = "Shop", on date: Date, category: Category? = nil, account: Account? = nil) -> Transaction {
        Transaction(kind: .expense, amount: Money(amount), merchant: merchant, date: date, categoryID: category?.id, accountID: account?.id)
    }

    static func income(_ amount: Decimal, on date: Date, account: Account? = nil) -> Transaction {
        Transaction(kind: .income, amount: Money(amount), merchant: "Paycheque", date: date, accountID: account?.id)
    }
}
