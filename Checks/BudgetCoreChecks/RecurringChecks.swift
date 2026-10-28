import Foundation
import CheckKit
import BudgetCore

func recurringChecks() {
    typealias F = CoreFixtures
    let scheduler = RecurringScheduler(calendar: F.utc)

    suite("RecurringScheduler") {
        check("monthly: one occurrence per month through now") {
            let rule = RecurringRule(merchant: "Claude", amount: Money(31.36), frequency: .monthly, startDate: F.date(2026, 8, 5))
            let due = scheduler.dueOccurrences(for: rule, now: F.date(2026, 10, 28))
            expectEqual(due, [F.date(2026, 8, 5), F.date(2026, 9, 5), F.date(2026, 10, 5)])
            // Not yet due on the 4th.
            expectEqual(scheduler.dueOccurrences(for: rule, now: F.date(2026, 10, 4)).count, 2)
            // Inclusive of now.
            expectEqual(scheduler.dueOccurrences(for: rule, now: F.date(2026, 10, 5)).count, 3)
            // Not started yet.
            expect(scheduler.dueOccurrences(for: rule, now: F.date(2026, 8, 4)).isEmpty)
        }
        check("monthly on the 31st clamps to month end without drifting") {
            let rule = RecurringRule(merchant: "Rent", amount: Money(1500), frequency: .monthly, startDate: F.date(2026, 1, 31))
            let due = scheduler.dueOccurrences(for: rule, now: F.date(2026, 5, 31, 23))
            expectEqual(due, [F.date(2026, 1, 31), F.date(2026, 2, 28), F.date(2026, 3, 31), F.date(2026, 4, 30), F.date(2026, 5, 31)])
        }
        check("biweekly steps two weeks (and interval multiplies)") {
            let rule = RecurringRule(merchant: "Paycheque", amount: Money(1000), kind: .income, frequency: .biweekly, startDate: F.date(2026, 10, 1))
            expectEqual(scheduler.dueOccurrences(for: rule, now: F.date(2026, 10, 30)), [F.date(2026, 10, 1), F.date(2026, 10, 15), F.date(2026, 10, 29)])
            var every2 = rule
            every2.interval = 2
            expectEqual(scheduler.dueOccurrences(for: every2, now: F.date(2026, 11, 30)), [F.date(2026, 10, 1), F.date(2026, 10, 29), F.date(2026, 11, 26)])
        }
        check("weekly, daily and yearly") {
            let weekly = RecurringRule(merchant: "W", amount: Money(1), frequency: .weekly, startDate: F.date(2026, 10, 1))
            expectEqual(scheduler.dueOccurrences(for: weekly, now: F.date(2026, 10, 22)).count, 4)
            let daily = RecurringRule(merchant: "D", amount: Money(1), frequency: .daily, startDate: F.date(2026, 10, 1))
            expectEqual(scheduler.dueOccurrences(for: daily, now: F.date(2026, 10, 10)).count, 10)
            let yearly = RecurringRule(merchant: "Y", amount: Money(1), frequency: .yearly, startDate: F.date(2024, 2, 29))
            expectEqual(scheduler.dueOccurrences(for: yearly, now: F.date(2026, 10, 1)), [F.date(2024, 2, 29), F.date(2025, 2, 28), F.date(2026, 2, 28)])
        }
        check("paused rules produce nothing") {
            var rule = RecurringRule(merchant: "Claude", amount: Money(31.36), frequency: .monthly, startDate: F.date(2026, 8, 5))
            rule.isPaused = true
            expect(scheduler.dueOccurrences(for: rule, now: F.date(2026, 10, 28)).isEmpty)
        }
        check("already generated periods are skipped") {
            var rule = RecurringRule(merchant: "Claude", amount: Money(31.36), frequency: .monthly, startDate: F.date(2026, 8, 5))
            rule.generatedPeriodKeys = ["2026-08", "2026-10"]
            expectEqual(scheduler.dueOccurrences(for: rule, now: F.date(2026, 10, 28)), [F.date(2026, 9, 5)])
            rule.generatedPeriodKeys.append("2026-09")
            expect(scheduler.dueOccurrences(for: rule, now: F.date(2026, 10, 28)).isEmpty)
        }
        check("endDate caps the series (inclusive)") {
            var rule = RecurringRule(merchant: "Gym", amount: Money(50), frequency: .monthly, startDate: F.date(2026, 1, 10))
            rule.endDate = F.date(2026, 3, 10)
            expectEqual(scheduler.dueOccurrences(for: rule, now: F.date(2026, 10, 28)).count, 3)
        }
        check("period keys and generated transactions") {
            let monthly = RecurringRule(merchant: "Claude", amount: Money(31.36), categoryID: UUID(), accountID: UUID(), frequency: .monthly, startDate: F.date(2026, 10, 5))
            expectEqual(scheduler.periodKey(for: monthly, on: F.date(2026, 10, 5)), "2026-10")
            var weekly = monthly
            weekly.frequency = .weekly
            expectEqual(scheduler.periodKey(for: weekly, on: F.date(2026, 10, 28)), "2026-W44")
            // ISO-ish week-year at the year boundary: Dec 31 2024 (Tue) is in week 1 of 2025 for Monday-start locales.
            var daily = monthly
            daily.frequency = .daily
            expectEqual(scheduler.periodKey(for: daily, on: F.date(2026, 3, 9)), "2026-03-09")
            var yearly = monthly
            yearly.frequency = .yearly
            expectEqual(scheduler.periodKey(for: yearly, on: F.date(2026, 3, 9)), "2026")
            let transaction = scheduler.transaction(for: monthly, on: F.date(2026, 10, 5))
            expectEqual(transaction.source, .recurring)
            expectEqual(transaction.recurringRuleID, monthly.id)
            expectEqual(transaction.amount, monthly.amount)
            expectEqual(transaction.externalFingerprint, "recurring|\(monthly.id.uuidString)|2026-10")
        }
    }
}
