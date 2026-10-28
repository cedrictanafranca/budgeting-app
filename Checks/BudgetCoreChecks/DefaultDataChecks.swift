import Foundation
import CheckKit
import BudgetCore

func defaultDataChecks() {
    typealias F = CoreFixtures
    suite("DefaultData") {
        let categories = DefaultData.categories()
        let accounts = DefaultData.accounts()
        let now = F.date(2026, 10, 28, 14)

        check("sample transactions are deterministic and well-formed") {
            let a = DefaultData.sampleTransactions(categories: categories, accounts: accounts, now: now)
            let b = DefaultData.sampleTransactions(categories: categories, accounts: accounts, now: now)
            expectEqual(a, b)
            expect(a.count >= 35 && a.count <= 60, "count \(a.count)")
            expectEqual(Set(a.map(\.id)).count, a.count)
            expect(a.allSatisfy { $0.date <= now && $0.amount.amount > 0 })
            expect(zip(a, a.dropFirst()).allSatisfy { $0.date >= $1.date }, "newest first")
        }
        check("covers ~7 months, many categories, and several accounts") {
            let txns = DefaultData.sampleTransactions(categories: categories, accounts: accounts, now: now)
            let oldest = txns.map(\.date).min()!
            expect(now.timeIntervalSince(oldest) > 150 * 86_400, "spans > 5 months")
            expect(Set(txns.compactMap(\.categoryID)).count >= 8, "category variety")
            expect(Set(txns.compactMap(\.accountID)).count >= 3, "account variety")
            expect(txns.compactMap(\.categoryID).allSatisfy { id in categories.contains { $0.id == id } })
        }
        check("one income and one Claude subscription per month, one card payment transfer") {
            let txns = DefaultData.sampleTransactions(categories: categories, accounts: accounts, now: now)
            let cal = Calendar.current
            func months(_ list: [Transaction]) -> [String] {
                list.map { let c = cal.dateComponents([.year, .month], from: $0.date); return "\(c.year!)-\(c.month!)" }
            }
            let incomes = months(txns.filter { $0.kind == .income })
            expectEqual(incomes.count, Set(incomes).count, "one income per month")
            expect(incomes.count >= 6)
            let claude = months(txns.filter { $0.merchant == "Claude" })
            expectEqual(claude.count, Set(claude).count, "one Claude per month")
            expect(claude.count >= 6)
            let transfers = txns.filter { $0.kind == .transfer }
            expectEqual(transfers.count, 1)
            let chequing = accounts.first { $0.type == .chequing }!, card = accounts.first { $0.type == .creditCard }!
            expectEqual(transfers[0].accountID, chequing.id)
            expectEqual(transfers[0].transferToAccountID, card.id)
        }
        check("works with sparse inputs and keeps payments out of spending") {
            let one = DefaultData.sampleTransactions(categories: [], accounts: [], now: now)
            expect(one.allSatisfy { $0.categoryID == nil && $0.accountID == nil })
            let txns = DefaultData.sampleTransactions(categories: categories, accounts: accounts, now: now)
            let calc = F.calculator()
            let all = DateInterval(start: F.date(2025, 1, 1, 0), end: now)
            let spent = calc.totalSpent(transactions: txns, in: all)
            let expenses = Money.sum(txns.filter { $0.kind == .expense }.map(\.amount))
            expectEqual(spent, expenses)
        }
        check("seeded rules cover the sample merchants") {
            let engine = CategorizationEngine(rules: CategorizationEngine.builtInRules(categories: categories), categories: categories, history: [])
            for txn in DefaultData.sampleTransactions(categories: categories, accounts: accounts, now: now) where txn.kind == .expense && !["Farmers Market", "Sushi Garden"].contains(txn.merchant) {
                expectEqual(engine.suggest(merchant: txn.merchant)?.categoryID, txn.categoryID, txn.merchant)
            }
        }
    }
}
