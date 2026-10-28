import Foundation
import CheckKit
import BudgetCore

func budgetCalculatorChecks() {
    typealias F = CoreFixtures
    let calc = F.calculator()

    suite("BudgetCalculator.intervals") {
        check("monthly interval is the calendar month") {
            let interval = calc.interval(for: .monthly, containing: F.date(2026, 10, 28))
            expectEqual(interval.start, F.date(2026, 10, 1, 0))
            expectEqual(interval.end, F.date(2026, 11, 1, 0))
        }
        check("weekly interval honours week start (Sunday vs Monday)") {
            // 2026-10-28 is a Wednesday.
            let sunday = F.calculator(weekStartsOn: 1).interval(for: .weekly, containing: F.date(2026, 10, 28))
            expectEqual(sunday.start, F.date(2026, 10, 25, 0))
            expectEqual(sunday.end, F.date(2026, 11, 1, 0))
            let monday = F.calculator(weekStartsOn: 2).interval(for: .weekly, containing: F.date(2026, 10, 28))
            expectEqual(monday.start, F.date(2026, 10, 26, 0))
            expectEqual(monday.end, F.date(2026, 11, 2, 0))
            // On the week-start day itself the week starts that day.
            let onMonday = F.calculator(weekStartsOn: 2).interval(for: .weekly, containing: F.date(2026, 10, 26, 8))
            expectEqual(onMonday.start, F.date(2026, 10, 26, 0))
        }
        check("savings is all-time") {
            let interval = calc.interval(for: .savings, containing: F.date(2026, 10, 28))
            expectEqual(interval.start, Date.distantPast)
            expectEqual(interval.end, Date.distantFuture)
            expectEqual(calc.interval(for: .savings, containing: Date(), offset: -5).start, Date.distantPast)
        }
        check("offsets cross year boundaries") {
            let back = calc.interval(for: .monthly, containing: F.date(2026, 1, 15), offset: -1)
            expectEqual(back.start, F.date(2025, 12, 1, 0))
            expectEqual(back.end, F.date(2026, 1, 1, 0))
            let forward = calc.interval(for: .monthly, containing: F.date(2025, 11, 15), offset: 3)
            expectEqual(forward.start, F.date(2026, 2, 1, 0))
            let farBack = calc.interval(for: .monthly, containing: F.date(2026, 3, 31), offset: -14)
            expectEqual(farBack.start, F.date(2025, 1, 1, 0))
            let week = F.calculator(weekStartsOn: 2).interval(for: .weekly, containing: F.date(2026, 1, 1), offset: -1)
            expectEqual(week.start, F.date(2025, 12, 22, 0))
            expectEqual(calc.interval(for: .monthly, containing: F.date(2026, 5, 5), offset: 0), calc.interval(for: .monthly, containing: F.date(2026, 5, 5)))
        }
        check("daysLeft counts today and treats the end as exclusive") {
            let october = calc.interval(for: .monthly, containing: F.date(2026, 10, 1))
            expectEqual(calc.daysLeft(in: october, from: F.date(2026, 10, 31, 23, 59)), 1)
            expectEqual(calc.daysLeft(in: october, from: F.date(2026, 10, 28, 9)), 4)
            expectEqual(calc.daysLeft(in: october, from: F.date(2026, 10, 1, 0)), 31)
            expectEqual(calc.daysLeft(in: october, from: F.date(2026, 11, 3)), 0)
            let week = F.calculator().interval(for: .weekly, containing: F.date(2026, 10, 28))
            expectEqual(calc.daysLeft(in: week, from: F.date(2026, 10, 28)), 4)
        }
    }

    suite("BudgetCalculator.summary") {
        let now = F.date(2026, 10, 28)
        let coffee = Category(name: "Coffee", emoji: "☕️", colorHex: "#111111", period: .weekly, budget: Money(20), sortOrder: 0)
        let eating = Category(name: "Eating out", emoji: "🍽️", colorHex: "#222222", period: .weekly, budget: nil, sortOrder: 1)
        let gas = Category(name: "Gas", emoji: "⛽️", colorHex: "#333333", period: .monthly, budget: Money(100), sortOrder: 2)
        let archived = Category(name: "Old", emoji: "🗄", colorHex: "#444444", period: .weekly, budget: Money(50), sortOrder: 3, isArchived: true)
        let vacation = Category(name: "Vacation", emoji: "🌴", colorHex: "#555555", period: .savings, budget: Money(1000), sortOrder: 4)
        let noTarget = Category(name: "Rainy day", emoji: "☔️", colorHex: "#666666", period: .savings, budget: nil, sortOrder: 5)
        let categories = [coffee, eating, gas, archived, vacation, noTarget]

        check("weekly summary counts only expenses in this week and sums budgets") {
            let txns = [
                F.expense(6.5, on: F.date(2026, 10, 26), category: coffee),
                F.expense(4, on: F.date(2026, 10, 28), category: coffee),
                F.expense(9, on: F.date(2026, 10, 20), category: coffee),               // last week
                F.expense(30, on: F.date(2026, 10, 27), category: eating),
                Transaction(kind: .income, amount: Money(500), merchant: "Refund", date: F.date(2026, 10, 27), categoryID: coffee.id),
                Transaction(kind: .transfer, amount: Money(200), merchant: "Move", date: F.date(2026, 10, 27), categoryID: coffee.id),
                F.expense(12, on: F.date(2026, 10, 27), category: archived),
            ]
            let summary = F.calculator(weekStartsOn: 2).summary(period: .weekly, categories: categories, transactions: txns, on: now)
            expectEqual(summary.categories.map(\.category.name), ["Coffee", "Eating out"])
            expectEqual(summary.categories[0].spent.amount, Decimal(string: "10.5")!)
            expectEqual(summary.categories[0].transactionCount, 2)
            expectEqual(summary.categories[0].remaining?.amount, Decimal(string: "9.5")!)
            expectEqual(summary.categories[0].progress ?? -1, 0.525)
            expect(summary.categories[1].budgeted == nil && summary.categories[1].remaining == nil && summary.categories[1].progress == nil)
            expectEqual(summary.categories[1].spent.amount, 30)
            expectEqual(summary.budgeted.amount, 20)
            expectEqual(summary.spent.amount, Decimal(string: "40.5")!)
            expectEqual(summary.remaining.amount, Decimal(string: "-20.5")!)
            expectEqual(summary.daysLeft, 5)   // Wed 28, Thu 29, Fri 30, Sat 31, Sun Nov 1
        }
        check("monthly summary and over-budget progress") {
            let txns = [F.expense(60, on: F.date(2026, 10, 3), category: gas), F.expense(70, on: F.date(2026, 10, 28), category: gas), F.expense(99, on: F.date(2026, 9, 28), category: gas)]
            let summary = calc.summary(period: .monthly, categories: categories, transactions: txns, on: now)
            expectEqual(summary.categories.count, 1)
            expectEqual(summary.spent.amount, 130)
            expectEqual(summary.remaining.amount, -30)
            expectEqual(summary.categories[0].progress ?? 0, 1.3)
            expectEqual(summary.daysLeft, 4)
            expectEqual(summary.interval, calc.interval(for: .monthly, containing: now))
        }
        check("savings categories are funded all-time") {
            let txns = [
                F.expense(250, on: F.date(2024, 3, 1), category: vacation),
                F.expense(100, on: F.date(2026, 10, 1), category: vacation),
                F.expense(40, on: F.date(2026, 10, 5), category: noTarget),
            ]
            let summary = calc.summary(period: .savings, categories: categories, transactions: txns, on: now)
            expectEqual(summary.categories.map(\.category.name), ["Vacation", "Rainy day"])
            expectEqual(summary.categories[0].spent.amount, 350)
            expectEqual(summary.categories[0].remaining?.amount, 650)
            expectEqual(summary.categories[0].progress ?? 0, 0.35)
            expectEqual(summary.categories[1].spent.amount, 40)
            expect(summary.categories[1].remaining == nil && summary.categories[1].progress == nil)
            expectEqual(summary.budgeted.amount, 1000)
            expectEqual(summary.spent.amount, 390)
        }
        check("empty inputs give zeroes") {
            let summary = calc.summary(period: .monthly, categories: [], transactions: [], on: now)
            expect(summary.categories.isEmpty && summary.budgeted.isZero && summary.spent.isZero && summary.remaining.isZero)
        }
    }

    suite("BudgetCalculator.series") {
        check("dailyTotals zero-fills every day, ascending, expenses only") {
            let interval = calc.interval(for: .monthly, containing: F.date(2026, 2, 10))
            let txns = [
                F.expense(10, on: F.date(2026, 2, 1, 0, 0)),
                F.expense(5, on: F.date(2026, 2, 1, 23, 59)),
                F.expense(7, on: F.date(2026, 2, 28, 12)),
                F.income(1000, on: F.date(2026, 2, 2)),
                F.expense(99, on: F.date(2026, 3, 1, 0, 0)),   // just outside
            ]
            let days = calc.dailyTotals(transactions: txns, in: interval)
            expectEqual(days.count, 28)
            expectEqual(days.first?.day, F.date(2026, 2, 1, 0))
            expectEqual(days.last?.day, F.date(2026, 2, 28, 0))
            expectEqual(days[0].total.amount, 15)
            expectEqual(days[1].total.amount, 0)
            expectEqual(days[27].total.amount, 7)
            expect(zip(days, days.dropFirst()).allSatisfy { $0.day < $1.day })
        }
        check("dailyTotals clamps long intervals to the last 90 days") {
            let all = DateInterval(start: .distantPast, end: .distantFuture)
            let now = F.date(2026, 10, 28, 15)
            let txns = [F.expense(10, on: F.date(2026, 10, 28, 9)), F.expense(5, on: F.date(2026, 8, 1)), F.expense(77, on: F.date(2020, 1, 1))]
            let days = calc.dailyTotals(transactions: txns, in: all, now: now)
            expectEqual(days.count, 90)
            expectEqual(days.last?.day, F.date(2026, 10, 28, 0))
            expectEqual(days.first?.day, F.date(2026, 7, 31, 0))
            expectEqual(days.last?.total.amount, 10)
            expectEqual(Money.sum(days.map(\.total)).amount, 15)
            // A long interval that ended in the past ends at interval.end instead of today.
            let past = DateInterval(start: F.date(2019, 1, 1, 0), end: F.date(2021, 1, 1, 0))
            let pastDays = calc.dailyTotals(transactions: txns, in: past, now: now)
            expectEqual(pastDays.count, 90)
            expectEqual(pastDays.last?.day, F.date(2020, 12, 31, 0))
        }
        check("monthlyTotals: last N months, oldest first, zero-filled, year boundary") {
            let txns = [
                F.expense(100, on: F.date(2026, 1, 20)),
                F.expense(50, on: F.date(2025, 11, 2)),
                F.income(2000, on: F.date(2026, 1, 1)),
                F.income(2000, on: F.date(2025, 12, 1)),
                Transaction(kind: .transfer, amount: Money(999), merchant: "Card payment", date: F.date(2026, 1, 15)),
                F.expense(1, on: F.date(2025, 9, 30)),   // outside window
            ]
            let totals = calc.monthlyTotals(transactions: txns, months: 3, endingAt: F.date(2026, 1, 31, 23))
            expectEqual(totals.map(\.month), [F.date(2025, 11, 1, 0), F.date(2025, 12, 1, 0), F.date(2026, 1, 1, 0)])
            expectEqual(totals.map(\.spent.amount), [50, 0, 100])
            expectEqual(totals.map(\.income.amount), [0, 2000, 2000])
            expect(calc.monthlyTotals(transactions: txns, months: 0).isEmpty)
            expectEqual(calc.monthlyTotals(transactions: [], months: 12, endingAt: F.date(2026, 6, 1)).count, 12)
        }
        check("cumulativeDailySpend is a running total per day") {
            let interval = DateInterval(start: F.date(2026, 10, 1, 0), end: F.date(2026, 10, 6, 0))
            let txns = [F.expense(10, on: F.date(2026, 10, 1)), F.expense(5, on: F.date(2026, 10, 3)), F.expense(2.5, on: F.date(2026, 10, 3, 18))]
            let line = calc.cumulativeDailySpend(transactions: txns, in: interval)
            expectEqual(line.map(\.total.amount), [10, 10, Decimal(string: "17.5")!, Decimal(string: "17.5")!, Decimal(string: "17.5")!])
        }
        check("totalSpent / totalIncome ignore other kinds") {
            let interval = calc.interval(for: .monthly, containing: F.date(2026, 10, 1))
            let txns = [F.expense(10, on: F.date(2026, 10, 5)), F.income(100, on: F.date(2026, 10, 6)),
                        Transaction(kind: .transfer, amount: Money(50), merchant: "t", date: F.date(2026, 10, 7))]
            expectEqual(calc.totalSpent(transactions: txns, in: interval).amount, 10)
            expectEqual(calc.totalIncome(transactions: txns, in: interval).amount, 100)
        }
    }

    suite("BudgetCalculator.balance") {
        let opening = F.date(2026, 1, 1, 0)
        let chequing = Account(name: "Chequing", type: .chequing, openingBalance: Money(1000), openingDate: opening)
        let savings = Account(name: "Savings", type: .savings, openingBalance: Money(500), openingDate: opening)
        let card = Account(name: "Visa", type: .creditCard, openingBalance: Money(200), openingDate: opening)
        let cash = Account(name: "Cash", type: .cash, openingBalance: Money(0), openingDate: opening)

        check("bank account: income adds, expense and transfer out subtract, transfer in adds") {
            let txns = [
                F.income(2000, on: F.date(2026, 2, 1), account: chequing),
                F.expense(120, on: F.date(2026, 2, 2), account: chequing),
                Transaction(kind: .transfer, amount: Money(300), merchant: "To savings", date: F.date(2026, 2, 3), accountID: chequing.id, transferToAccountID: savings.id),
                Transaction(kind: .transfer, amount: Money(50), merchant: "From savings", date: F.date(2026, 2, 4), accountID: savings.id, transferToAccountID: chequing.id),
                F.expense(40, on: F.date(2026, 2, 5), account: cash),   // other account
            ]
            expectEqual(calc.balance(for: chequing, transactions: txns).amount, 1000 + 2000 - 120 - 300 + 50)
            expectEqual(calc.balance(for: savings, transactions: txns).amount, 500 + 300 - 50)
            expectEqual(calc.balance(for: cash, transactions: txns).amount, -40)
        }
        check("transactions before the opening date are ignored") {
            let txns = [F.expense(500, on: F.date(2025, 12, 31), account: chequing), F.expense(10, on: opening, account: chequing)]
            expectEqual(calc.balance(for: chequing, transactions: txns).amount, 990)
        }
        check("credit card payment: reduces chequing and card owed, never counts as spending") {
            let purchase = F.expense(150, "Costco", on: F.date(2026, 3, 1), account: card)
            let payment = Transaction(kind: .transfer, amount: Money(300), merchant: "Credit Card Payment", date: F.date(2026, 3, 10), accountID: chequing.id, transferToAccountID: card.id)
            let refund = Transaction(kind: .income, amount: Money(25), merchant: "Refund", date: F.date(2026, 3, 12), accountID: card.id)
            let txns = [purchase, payment, refund]
            // Card: owed 200 + 150 purchase - 300 payment - 25 refund = 25
            expectEqual(calc.balance(for: card, transactions: txns).amount, 25)
            // Chequing: 1000 - 300
            expectEqual(calc.balance(for: chequing, transactions: txns).amount, 700)
            // Net position moves only by what was actually spent: 150 purchase - 25 refund.
            let before = Decimal(1000 - 200)
            let after = calc.balance(for: chequing, transactions: txns).amount - calc.balance(for: card, transactions: txns).amount
            expectEqual(after, before - 150 + 25)
            // The payment is not spending anywhere.
            let march = calc.interval(for: .monthly, containing: F.date(2026, 3, 15))
            expectEqual(calc.totalSpent(transactions: txns, in: march).amount, 150)
            var categorized = txns
            let monthly = Category(name: "Groceries", emoji: "🛒", colorHex: "#00FF00", period: .monthly, budget: Money(500))
            categorized[0].categoryID = monthly.id
            categorized[1].categoryID = monthly.id   // even if mislabelled, a transfer is not an expense
            let summary = calc.summary(period: .monthly, categories: [monthly], transactions: categorized, on: F.date(2026, 3, 15))
            expectEqual(summary.spent.amount, 150)
            let breakdown = calc.spendingByCategory(transactions: categorized, categories: [monthly], in: march)
            expectEqual(breakdown.map(\.spent.amount), [150])
            let daily = calc.dailyTotals(transactions: txns, in: march)
            expectEqual(Money.sum(daily.map(\.total)).amount, 150)
        }
        check("lastActivity finds the newest touching transaction") {
            let txns = [F.expense(1, on: F.date(2026, 2, 1), account: chequing),
                        Transaction(kind: .transfer, amount: Money(5), merchant: "p", date: F.date(2026, 2, 9), accountID: savings.id, transferToAccountID: chequing.id)]
            expectEqual(calc.lastActivity(for: chequing, transactions: txns), F.date(2026, 2, 9))
            expect(calc.lastActivity(for: card, transactions: txns) == nil)
        }
    }

    suite("BudgetCalculator.spendingByCategory") {
        check("groups, sorts by spent descending, handles uncategorized and unknown categories") {
            let food = Category(name: "Food", emoji: "🍔", colorHex: "#111111", budget: Money(200), sortOrder: 0)
            let fun = Category(name: "Fun", emoji: "🎟", colorHex: "#222222", budget: nil, sortOrder: 1)
            let gone = Category(name: "Deleted", emoji: "x", colorHex: "#333333")
            let interval = calc.interval(for: .monthly, containing: F.date(2026, 10, 1))
            let txns = [
                F.expense(30, on: F.date(2026, 10, 2), category: food),
                F.expense(20, on: F.date(2026, 10, 3), category: food),
                F.expense(80, on: F.date(2026, 10, 4), category: fun),
                F.expense(10, on: F.date(2026, 10, 5)),
                F.expense(500, on: F.date(2026, 10, 6), category: gone),
                F.expense(1000, on: F.date(2026, 9, 6), category: food),
                F.income(999, on: F.date(2026, 10, 6)),
            ]
            let result = calc.spendingByCategory(transactions: txns, categories: [food, fun], in: interval)
            expectEqual(result.map(\.category.name), ["Fun", "Food", "Uncategorized"])
            expectEqual(result.map(\.spent.amount), [80, 50, 10])
            expectEqual(result[1].remaining?.amount, 150)
            expectEqual(result[1].progress ?? 0, 0.25)
            expectEqual(result[1].transactionCount, 2)
            expect(result[0].budgeted == nil && result[0].progress == nil)
            let uncategorized = result[2].category
            expectEqual(uncategorized.id, UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
            expectEqual(uncategorized.emoji, "❔")
            expectEqual(uncategorized.colorHex, "#9CA3AF")
            expect(result[2].budgeted == nil)
        }
    }
}
