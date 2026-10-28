import Foundation

/// Seed data for first launch and previews. Mirrors the Luna reference categories.
public enum DefaultData {
    public static func categories() -> [Category] {
        // Weekly group
        let weekly: [(String, String, String)] = [
            ("Clothes", "👕", "#111827"),
            ("Coffee shops", "☕️", "#F472B6"),
            ("Eating out", "🍽️", "#1E3A8A"),
            ("Going out", "🍸", "#EC4899"),
            ("Misc spending", "🧾", "#60A5FA"),
            ("Subscriptions", "💳", "#111827"),
            ("Ubers/Lyft", "🚗", "#F472B6"),
            ("Groceries", "🛒", "#22C55E"),
        ]
        let monthly: [(String, String, String)] = [
            ("Entertainment", "🎟️", "#F59E0B"),
            ("Fitness", "🏋️", "#EF4444"),
            ("Gas", "⛽️", "#2563EB"),
            ("Gifts", "🎁", "#A855F7"),
            ("Travel", "✈️", "#111827"),
            ("Shopping", "🛍️", "#F97316"),
            ("Health", "💊", "#14B8A6"),
            ("Personal care", "🧴", "#F43F5E"),
            ("Transportation", "🚌", "#0EA5E9"),
            ("Other", "📦", "#6B7280"),
        ]
        let savings: [(String, String, String)] = [
            ("Big Purchase", "💰", "#9CA3AF"),
            ("Vacation", "🌴", "#22C55E"),
        ]
        var result: [Category] = []
        var order = 0
        for (name, emoji, color) in weekly {
            result.append(Category(name: name, emoji: emoji, colorHex: color, period: .weekly, budget: nil, sortOrder: order)); order += 1
        }
        for (name, emoji, color) in monthly {
            result.append(Category(name: name, emoji: emoji, colorHex: color, period: .monthly, budget: nil, sortOrder: order)); order += 1
        }
        for (name, emoji, color) in savings {
            result.append(Category(name: name, emoji: emoji, colorHex: color, period: .savings, budget: nil, sortOrder: order)); order += 1
        }
        return result
    }

    /// Seeded accounts open far in the past so back-dated transactions (imports, samples) count toward balances.
    public static let seededOpeningDate = Date(timeIntervalSince1970: 1_577_836_800) // 2020-01-01

    public static func accounts() -> [Account] {
        [
            Account(name: "Chequing", type: .chequing, openingDate: seededOpeningDate, colorHex: "#2563EB", sortOrder: 0, isDefaultForExpenses: true),
            Account(name: "Credit Card", type: .creditCard, openingDate: seededOpeningDate, colorHex: "#5B3DF5", sortOrder: 1),
            Account(name: "Cash", type: .cash, openingDate: seededOpeningDate, colorHex: "#22C55E", sortOrder: 2),
        ]
    }

    /// Realistic, deterministic sample transactions for previews: ~7 months across many categories and
    /// accounts, one paycheque and one Claude subscription per month, one credit card payment (transfer),
    /// plus a few purchases in the last week. Dates are relative to `now`; ids and amounts are fixed so
    /// previews are stable.
    public static func sampleTransactions(categories: [Category], accounts: [Account], now: Date = Date()) -> [Transaction] {
        let calendar = Calendar.current
        func cat(_ name: String) -> UUID? { categories.first { $0.name == name }?.id }
        let chequing = accounts.first { $0.type == .chequing } ?? accounts.first
        let card = accounts.first { $0.type == .creditCard } ?? chequing
        let cash = accounts.first { $0.type == .cash } ?? chequing

        var result: [Transaction] = []
        var counter = 0

        /// Deterministic pseudo-variation (no randomness): cents added on top of a base amount.
        func amount(_ baseCents: Int, _ seed: Int) -> Money {
            let jitter = ((seed &* 7919 &+ 104_729) % 1_300 + 1_300) % 1_300
            return Money(Decimal(baseCents + jitter) / 100)
        }
        func date(monthsBack: Int, day: Int, hour: Int = 12) -> Date? {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthsBack, to: now),
                  var parts = Optional(calendar.dateComponents([.year, .month], from: monthDate)) else { return nil }
            parts.day = day
            parts.hour = hour
            return calendar.date(from: parts)
        }
        func add(_ money: Money, _ merchant: String, kind: TransactionKind = .expense, on when: Date?, category: String? = nil, account: Account?, to destination: Account? = nil, note: String? = nil) {
            guard let when, when <= now else { return }
            counter += 1
            let id = UUID(uuidString: String(format: "5A3B1E00-0000-4000-8000-%012d", counter))!
            result.append(Transaction(
                id: id, kind: kind, amount: money, merchant: merchant, note: note, date: when,
                categoryID: category.flatMap(cat), accountID: account?.id, transferToAccountID: destination?.id,
                source: .manual, createdAt: when, updatedAt: when
            ))
        }

        for back in 0...6 {
            let seed = back + 1
            add(Money(2_150.00), "Paycheque", kind: .income, on: date(monthsBack: back, day: 1, hour: 9), account: chequing)
            add(Money(31.36), "Claude", on: date(monthsBack: back, day: 5, hour: 8), category: "Subscriptions", account: card, note: "Monthly subscription")
            if back == 0 { continue }   // current month: the "recent" purchases below fill in the rest

            add(amount(6_000, seed), back % 2 == 0 ? "Costco" : "Safeway", on: date(monthsBack: back, day: back % 2 == 0 ? 8 : 19), category: "Groceries", account: card)
            add(amount(450, seed * 3), "Starbucks", on: date(monthsBack: back, day: 11, hour: 8), category: "Coffee shops", account: chequing)
            switch back % 3 {
            case 0: add(amount(3_800, seed), "Sushi Garden", on: date(monthsBack: back, day: 14, hour: 19), category: "Eating out", account: card)
            case 1: add(amount(1_500, seed), "Uber", on: date(monthsBack: back, day: 14, hour: 22), category: "Ubers/Lyft", account: card)
            default: add(amount(2_800, seed), "Cineplex", on: date(monthsBack: back, day: 14, hour: 20), category: "Entertainment", account: card)
            }
            if back % 2 == 0 {
                add(amount(5_200, seed), "Shell", on: date(monthsBack: back, day: 17, hour: 17), category: "Gas", account: card)
            } else {
                add(Money(54.99), "GoodLife Fitness", on: date(monthsBack: back, day: 2, hour: 7), category: "Fitness", account: chequing)
            }
            if back == 1 {
                add(amount(8_900, seed), "Amazon", on: date(monthsBack: back, day: 23, hour: 15), category: "Shopping", account: card)
                // Paying the credit card is a transfer, never spending.
                if let chequing, let card, chequing.id != card.id {
                    add(Money(450.00), "Credit Card Payment", kind: .transfer, on: date(monthsBack: back, day: 25, hour: 10), account: chequing, to: card)
                }
            }
            if back == 2 {
                add(Money(23.50), "Farmers Market", on: date(monthsBack: back, day: 21, hour: 11), category: "Groceries", account: cash)
            }
        }

        // Recent activity so "this week" views are never empty.
        let day: TimeInterval = 86_400
        add(Money(6.45), "Starbucks", on: now.addingTimeInterval(-1 * day), category: "Coffee shops", account: chequing)
        add(Money(84.12), "Costco", on: now.addingTimeInterval(-3 * day), category: "Groceries", account: card)
        add(Money(18.90), "Uber", on: now.addingTimeInterval(-4 * day), category: "Ubers/Lyft", account: card)
        add(Money(42.00), "Sushi Garden", on: now.addingTimeInterval(-6 * day), category: "Eating out", account: card)

        return result.sorted { ($0.date, $0.id.uuidString) > ($1.date, $1.id.uuidString) }
    }
}
