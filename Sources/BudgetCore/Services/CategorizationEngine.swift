import Foundation

public struct CategorySuggestion: Hashable, Sendable {
    public enum Reason: String, Sendable { case userRule, builtInRule, history, fallback }
    public var categoryID: UUID
    public var displayName: String?
    public var confidence: Double
    public var reason: Reason
    public init(categoryID: UUID, displayName: String? = nil, confidence: Double, reason: Reason) {
        self.categoryID = categoryID
        self.displayName = displayName
        self.confidence = confidence
        self.reason = reason
    }
}

public struct MerchantSuggestion: Hashable, Identifiable, Sendable {
    public var name: String
    public var categoryID: UUID?
    public var lastAmount: Money?
    public var useCount: Int
    public var id: String { name.lowercased() }
    public init(name: String, categoryID: UUID?, lastAmount: Money?, useCount: Int) {
        self.name = name
        self.categoryID = categoryID
        self.lastAmount = lastAmount
        self.useCount = useCount
    }
}

/// Deterministic, offline categorization. Precedence:
/// 1. user-defined MerchantRule (exact normalized match, then longest substring)
/// 2. built-in MerchantRule
/// 3. most frequent category for this merchant in `history`
/// 4. fallback category (the one named "Other"/"Misc", else nil)
/// Designed so an ML/LLM classifier can be slotted in as step 3.5 later.
public struct CategorizationEngine: Sendable {
    public var rules: [MerchantRule]
    public var categories: [Category]
    public var history: [Transaction]

    public init(rules: [MerchantRule], categories: [Category], history: [Transaction]) {
        self.rules = rules
        self.categories = categories
        self.history = history
    }

    /// Lowercase, strip punctuation / payment-processor prefixes ("SQ *", "TST*", "PAYPAL *"), collapse whitespace, drop trailing store numbers.
    public static func normalize(_ merchant: String) -> String {
        // TODO(core-agent): full implementation + tests
        return merchant.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Human-friendly merchant name from a raw Wallet string ("SQ *BLUE BOTTLE #12" → "Blue Bottle").
    public static func cleanDisplayName(_ merchant: String) -> String {
        // TODO(core-agent)
        return merchant.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func suggest(merchant: String) -> CategorySuggestion? {
        // TODO(core-agent): implement precedence described above
        let normalized = Self.normalize(merchant)
        if let rule = rules.filter({ normalized.contains($0.pattern) }).sorted(by: { ($0.isUserDefined ? 1 : 0, $0.pattern.count) > ($1.isUserDefined ? 1 : 0, $1.pattern.count) }).first {
            return CategorySuggestion(categoryID: rule.categoryID, displayName: rule.displayName, confidence: rule.isUserDefined ? 1 : 0.8, reason: rule.isUserDefined ? .userRule : .builtInRule)
        }
        return fallbackCategory.map { CategorySuggestion(categoryID: $0.id, confidence: 0.1, reason: .fallback) }
    }

    /// Merchants matching `prefix` (empty = most used), for the quick-add autocomplete.
    public func merchantSuggestions(matching prefix: String, limit: Int = 8) -> [MerchantSuggestion] {
        // TODO(core-agent): rank by frequency then recency
        return []
    }

    public var fallbackCategory: Category? {
        categories.first { ["other", "misc", "misc spending", "miscellaneous"].contains($0.name.lowercased()) && !$0.isArchived }
    }

    /// Starter rules (Starbucks → Coffee, Uber → Transportation …) mapped onto the seeded categories by name.
    /// Rules whose target category name isn't present are skipped.
    public static func builtInRules(categories: [Category]) -> [MerchantRule] {
        // TODO(core-agent): expand to a solid Canadian/US list (~80 merchants) + tests
        func id(_ name: String) -> UUID? { categories.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.id }
        let seeds: [(String, String, String)] = [
            ("starbucks", "Coffee shops", "Starbucks"),
            ("tim hortons", "Coffee shops", "Tim Hortons"),
            ("uber", "Ubers/Lyft", "Uber"),
            ("lyft", "Ubers/Lyft", "Lyft"),
            ("netflix", "Subscriptions", "Netflix"),
            ("spotify", "Subscriptions", "Spotify"),
            ("walmart", "Groceries", "Walmart"),
            ("costco", "Groceries", "Costco"),
            ("amazon", "Shopping", "Amazon"),
        ]
        return seeds.compactMap { pattern, category, display in
            guard let categoryID = id(category) else { return nil }
            return MerchantRule(pattern: pattern, categoryID: categoryID, displayName: display, isUserDefined: false)
        }
    }
}
