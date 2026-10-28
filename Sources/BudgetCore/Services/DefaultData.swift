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

    public static func accounts() -> [Account] {
        [
            Account(name: "Chequing", type: .chequing, colorHex: "#2563EB", sortOrder: 0, isDefaultForExpenses: true),
            Account(name: "Credit Card", type: .creditCard, colorHex: "#5B3DF5", sortOrder: 1),
            Account(name: "Cash", type: .cash, colorHex: "#22C55E", sortOrder: 2),
        ]
    }

    /// Realistic sample transactions for previews (spread over the last ~6 weeks).
    public static func sampleTransactions(categories: [Category], accounts: [Account], now: Date = Date()) -> [Transaction] {
        // TODO(core-agent): richer sample set across categories/months for Reports previews
        func cat(_ name: String) -> UUID? { categories.first { $0.name == name }?.id }
        let account = accounts.first?.id
        let day: TimeInterval = 86_400
        return [
            Transaction(amount: Money(31.36), merchant: "Claude", date: now.addingTimeInterval(-1 * day), categoryID: cat("Subscriptions"), accountID: account),
            Transaction(amount: Money(6.45), merchant: "Starbucks", date: now.addingTimeInterval(-1 * day), categoryID: cat("Coffee shops"), accountID: account),
            Transaction(amount: Money(84.12), merchant: "Costco", date: now.addingTimeInterval(-3 * day), categoryID: cat("Groceries"), accountID: account),
            Transaction(amount: Money(18.90), merchant: "Uber", date: now.addingTimeInterval(-4 * day), categoryID: cat("Ubers/Lyft"), accountID: account),
            Transaction(amount: Money(42.00), merchant: "Sushi Garden", date: now.addingTimeInterval(-6 * day), categoryID: cat("Eating out"), accountID: account),
            Transaction(kind: .income, amount: Money(2_150.00), merchant: "Paycheque", date: now.addingTimeInterval(-10 * day), accountID: account),
        ]
    }
}
