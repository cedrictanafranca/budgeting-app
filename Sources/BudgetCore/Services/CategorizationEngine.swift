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

    // MARK: Normalization

    /// Words that precede a trailing store number ("store 55", "no 12") and are dropped with it.
    private static let storeNumberLeaders: Set<String> = ["store", "no", "unit", "location", "loc", "branch", "shop", "stn", "number"]

    /// Splits a raw merchant string into display tokens: processor prefixes removed, punctuation turned
    /// into separators (apostrophes and ampersands stay inside a word), trailing store numbers dropped.
    /// Case is preserved so `cleanDisplayName` can detect acronyms.
    private static func tokens(_ merchant: String) -> [String] {
        var text = merchant
            .folding(options: [.diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Payment-processor prefixes: "SQ *", "TST*", "PAYPAL *", "PP*", "DD *", "SP ".
        let prefixPattern = #"^(?:(?:sq|tst|paypal|pp|dd)\s*\*\s*|sp\s+)"#
        if let range = text.range(of: prefixPattern, options: [.regularExpression, .caseInsensitive]) {
            text.removeSubrange(range)
        }
        // Marketplace / billing prefixes that stand in for the real merchant.
        if let range = text.range(of: #"^amzn\s*mktp(?:\s+(?:ca|us))?"#, options: [.regularExpression, .caseInsensitive]) {
            text.replaceSubrange(range, with: "Amazon")
        } else if let range = text.range(of: #"^apple\.com/bill"#, options: [.regularExpression, .caseInsensitive]) {
            text.replaceSubrange(range, with: "Apple Bill")
        }

        // Punctuation becomes a separator; apostrophes and & stay inside words (McDonald's, A&W).
        let keep = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "&'’"))
        let cleaned = String(text.unicodeScalars.map { scalar -> Character in
            if keep.contains(scalar) { return Character(scalar) }
            return " "
        })
        var words = cleaned.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        // Words that are only punctuation after all ("&", "'") carry no meaning.
        words = words.filter { word in word.contains(where: { $0.isLetter || $0.isNumber }) }

        // Trailing store numbers / reference codes: "starbucks 2231", "iga store 55", "amazon 2k3xx".
        var droppedNumber = false
        while words.count > 1, let last = words.last, isReferenceToken(last) {
            words.removeLast()
            droppedNumber = true
        }
        if droppedNumber, words.count > 1, let last = words.last, storeNumberLeaders.contains(last.lowercased()) {
            words.removeLast()
        }
        return words
    }

    private static func isReferenceToken(_ word: String) -> Bool {
        let hasDigit = word.contains { $0.isNumber }
        guard hasDigit else { return false }
        if word.allSatisfy({ $0.isNumber }) { return true }
        // Mixed alphanumeric reference codes ("1a2b3c") — keep short ones like "7up" or "3m".
        return word.count >= 5 && word.contains { $0.isLetter }
    }

    /// Lowercase, strip punctuation / payment-processor prefixes ("SQ *", "TST*", "PAYPAL *"), collapse whitespace, drop trailing store numbers.
    public static func normalize(_ merchant: String) -> String {
        tokens(merchant)
            .flatMap { $0.split(separator: "&").map(String.init) }   // "A&W" → "a w", so "A & W" matches too
            .map { $0.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "") }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    /// Human-friendly merchant name from a raw Wallet string ("SQ *BLUE BOTTLE #12" → "Blue Bottle").
    /// Words are title-cased; short all-caps acronyms ("IGA", "A&W") and intentionally mixed-case words
    /// ("McDonald's") are kept as written.
    public static func cleanDisplayName(_ merchant: String) -> String {
        let words = tokens(merchant)
        guard !words.isEmpty else { return merchant.trimmingCharacters(in: .whitespacesAndNewlines) }
        return words.map(displayWord).joined(separator: " ")
    }

    private static let commonShortWords: Set<String> = ["a", "an", "and", "at", "by", "for", "in", "of", "on", "or", "the", "to"]

    private static func displayWord(_ word: String) -> String {
        let letters = word.filter { $0.isLetter }
        // Short all-caps words are acronyms ("IGA", "A&W") unless they're everyday words ("ON", "OF", "THE").
        if !Self.commonShortWords.contains(word.lowercased()), !letters.isEmpty, letters.count <= 3, letters.allSatisfy({ $0.isUppercase }) { return word }
        let dropped = word.dropFirst()
        if dropped.contains(where: { $0.isUppercase }) && word.contains(where: { $0.isLowercase }) { return word }
        // Capitalize each &-separated segment ("h&m" → "H&M").
        return word.split(separator: "&", omittingEmptySubsequences: false).map { segment -> String in
            guard let first = segment.first else { return "" }
            return first.uppercased() + segment.dropFirst().lowercased()
        }.joined(separator: "&")
    }

    // MARK: Matching

    /// True if `pattern` occurs in `text` as a run of whole words ("iga" matches "iga store" but not "tigard").
    private static func containsWords(_ text: String, _ pattern: String) -> Bool {
        guard !pattern.isEmpty else { return false }
        return " \(text) ".contains(" \(pattern) ")
    }

    private func isUsable(_ rule: MerchantRule) -> Bool {
        categories.isEmpty || categories.contains { $0.id == rule.categoryID }
    }

    private func better(_ a: MerchantRule, than b: MerchantRule) -> Bool {
        if a.pattern.count != b.pattern.count { return a.pattern.count > b.pattern.count }
        if a.hitCount != b.hitCount { return a.hitCount > b.hitCount }
        return a.pattern < b.pattern
    }

    private func suggestion(from rule: MerchantRule) -> CategorySuggestion {
        CategorySuggestion(
            categoryID: rule.categoryID,
            displayName: rule.displayName,
            confidence: rule.isUserDefined ? 1.0 : 0.8,
            reason: rule.isUserDefined ? .userRule : .builtInRule
        )
    }

    /// Precedence: user rule exact → user rule longest substring → built-in exact → built-in longest match →
    /// history → fallback category. Patterns shorter than 3 characters only ever match exactly.
    public func suggest(merchant: String) -> CategorySuggestion? {
        let normalized = Self.normalize(merchant)
        let usable = rules.filter(isUsable).map { rule -> (MerchantRule, String) in
            (rule, rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }.filter { !$0.1.isEmpty }
        let userRules = usable.filter { $0.0.isUserDefined }
        let builtIn = usable.filter { !$0.0.isUserDefined }

        if !normalized.isEmpty {
            // (a) user exact, (b) user longest substring
            if let rule = userRules.filter({ $0.1 == normalized }).map(\.0).sorted(by: better).first {
                return suggestion(from: rule)
            }
            let userSubstring = userRules.filter { $0.1.count >= 3 && normalized.contains($0.1) }.map(\.0).sorted(by: better)
            if let rule = userSubstring.first { return suggestion(from: rule) }

            // (c) built-in exact, (d) built-in longest whole-word match
            if let rule = builtIn.filter({ $0.1 == normalized }).map(\.0).sorted(by: better).first {
                return suggestion(from: rule)
            }
            let builtInMatches = builtIn.filter { $0.1.count >= 3 && Self.containsWords(normalized, $0.1) }.map(\.0).sorted(by: better)
            if let rule = builtInMatches.first { return suggestion(from: rule) }

            // (e) history: most frequent category for this merchant, ties → most recent
            if let categoryID = historyCategory(for: normalized) {
                return CategorySuggestion(categoryID: categoryID, confidence: 0.7, reason: .history)
            }
        }
        // (f) fallback
        return fallbackCategory.map { CategorySuggestion(categoryID: $0.id, confidence: 0.1, reason: .fallback) }
    }

    private func historyCategory(for normalizedMerchant: String) -> UUID? {
        var counts: [UUID: Int] = [:]
        var latest: [UUID: Date] = [:]
        for transaction in history where transaction.kind == .expense {
            guard let categoryID = transaction.categoryID,
                  Self.normalize(transaction.merchant) == normalizedMerchant else { continue }
            counts[categoryID, default: 0] += 1
            if let seen = latest[categoryID], seen >= transaction.date {} else { latest[categoryID] = transaction.date }
        }
        return counts.keys.sorted { a, b in
            if counts[a]! != counts[b]! { return counts[a]! > counts[b]! }
            if latest[a]! != latest[b]! { return latest[a]! > latest[b]! }
            return a.uuidString < b.uuidString
        }.first
    }

    // MARK: Autocomplete

    /// Merchants matching `prefix` (empty = most used), for the quick-add autocomplete.
    /// Groups history by cleaned, case-insensitive name; names starting with the prefix rank before names
    /// merely containing it; then by use count and recency.
    public func merchantSuggestions(matching prefix: String, limit: Int = 8) -> [MerchantSuggestion] {
        guard limit > 0 else { return [] }
        let query = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        struct Group {
            var name: String
            var latest: Transaction
            var count = 0
            var categoryCounts: [UUID: (count: Int, latest: Date)] = [:]
        }
        var groups: [String: Group] = [:]
        for transaction in history {
            let name = Self.cleanDisplayName(transaction.merchant)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            var group = groups[key] ?? Group(name: name, latest: transaction)
            group.count += 1
            if transaction.date >= group.latest.date {
                group.latest = transaction
                group.name = name
            }
            if let categoryID = transaction.categoryID {
                let current = group.categoryCounts[categoryID] ?? (0, .distantPast)
                group.categoryCounts[categoryID] = (current.count + 1, max(current.latest, transaction.date))
            }
            groups[key] = group
        }

        func rank(_ key: String) -> Int? {
            if query.isEmpty { return 0 }
            if key.hasPrefix(query) { return 0 }
            if key.contains(query) { return 1 }
            return nil
        }
        let ranked = groups.compactMap { key, group -> (Int, Group)? in
            guard let r = rank(key) else { return nil }
            return (r, group)
        }.sorted { a, b in
            if a.0 != b.0 { return a.0 < b.0 }
            if a.1.count != b.1.count { return a.1.count > b.1.count }
            if a.1.latest.date != b.1.latest.date { return a.1.latest.date > b.1.latest.date }
            return a.1.name < b.1.name
        }
        return ranked.prefix(limit).map { _, group in
            let bestCategory = group.categoryCounts.sorted { x, y in
                if x.value.count != y.value.count { return x.value.count > y.value.count }
                if x.value.latest != y.value.latest { return x.value.latest > y.value.latest }
                return x.key.uuidString < y.key.uuidString
            }.first?.key
            return MerchantSuggestion(name: group.name, categoryID: bestCategory, lastAmount: group.latest.amount, useCount: group.count)
        }
    }

    public var fallbackCategory: Category? {
        // Prefer "Other", then the Misc variants.
        for name in ["other", "misc", "misc spending", "miscellaneous"] {
            if let match = categories.first(where: { $0.name.lowercased() == name && !$0.isArchived }) { return match }
        }
        return nil
    }

    // MARK: Built-in rules

    /// (pattern, category name, display name). Patterns are normalized when the rules are built.
    private static let builtInSeeds: [(String, String, String)] = [
        // Coffee shops
        ("starbucks", "Coffee shops", "Starbucks"),
        ("tim hortons", "Coffee shops", "Tim Hortons"),
        ("blenz", "Coffee shops", "Blenz"),
        ("jj bean", "Coffee shops", "JJ Bean"),
        ("second cup", "Coffee shops", "Second Cup"),
        ("dunkin", "Coffee shops", "Dunkin'"),
        ("blue bottle", "Coffee shops", "Blue Bottle"),
        ("pret a manger", "Coffee shops", "Pret A Manger"),
        ("espresso", "Coffee shops", "Espresso"),
        // Eating out
        ("mcdonalds", "Eating out", "McDonald's"),
        ("a&w", "Eating out", "A&W"),
        ("subway", "Eating out", "Subway"),
        ("chipotle", "Eating out", "Chipotle"),
        ("doordash", "Eating out", "DoorDash"),
        ("ubereats", "Eating out", "Uber Eats"),
        ("uber eats", "Eating out", "Uber Eats"),
        ("skipthedishes", "Eating out", "SkipTheDishes"),
        ("skip the dishes", "Eating out", "SkipTheDishes"),
        ("burger king", "Eating out", "Burger King"),
        ("wendys", "Eating out", "Wendy's"),
        ("kfc", "Eating out", "KFC"),
        ("taco bell", "Eating out", "Taco Bell"),
        ("popeyes", "Eating out", "Popeyes"),
        ("pizza hut", "Eating out", "Pizza Hut"),
        ("dominos", "Eating out", "Domino's"),
        ("pizza pizza", "Eating out", "Pizza Pizza"),
        ("panago", "Eating out", "Panago"),
        ("five guys", "Eating out", "Five Guys"),
        ("chick fil a", "Eating out", "Chick-fil-A"),
        ("boston pizza", "Eating out", "Boston Pizza"),
        ("earls", "Eating out", "Earls"),
        ("white spot", "Eating out", "White Spot"),
        ("harveys", "Eating out", "Harvey's"),
        ("dairy queen", "Eating out", "Dairy Queen"),
        ("mucho burrito", "Eating out", "Mucho Burrito"),
        ("freshii", "Eating out", "Freshii"),
        // Groceries
        ("walmart", "Groceries", "Walmart"),
        ("wal mart", "Groceries", "Walmart"),
        ("costco", "Groceries", "Costco"),
        ("safeway", "Groceries", "Safeway"),
        ("save on foods", "Groceries", "Save-On-Foods"),
        ("loblaws", "Groceries", "Loblaws"),
        ("superstore", "Groceries", "Superstore"),
        ("no frills", "Groceries", "No Frills"),
        ("t&t", "Groceries", "T&T"),
        ("whole foods", "Groceries", "Whole Foods"),
        ("iga", "Groceries", "IGA"),
        ("sobeys", "Groceries", "Sobeys"),
        ("freshco", "Groceries", "FreshCo"),
        ("trader joes", "Groceries", "Trader Joe's"),
        ("urban fare", "Groceries", "Urban Fare"),
        ("h mart", "Groceries", "H Mart"),
        ("instacart", "Groceries", "Instacart"),
        // Ubers/Lyft
        ("uber", "Ubers/Lyft", "Uber"),
        ("lyft", "Ubers/Lyft", "Lyft"),
        // Transportation
        ("translink", "Transportation", "TransLink"),
        ("compass", "Transportation", "Compass"),
        ("presto", "Transportation", "Presto"),
        ("go transit", "Transportation", "GO Transit"),
        ("ttc", "Transportation", "TTC"),
        ("evo", "Transportation", "Evo"),
        ("modo", "Transportation", "Modo"),
        ("bc ferries", "Transportation", "BC Ferries"),
        ("via rail", "Transportation", "VIA Rail"),
        ("easypark", "Transportation", "EasyPark"),
        ("impark", "Transportation", "Impark"),
        // Subscriptions
        ("netflix", "Subscriptions", "Netflix"),
        ("spotify", "Subscriptions", "Spotify"),
        ("apple.com/bill", "Subscriptions", "Apple"),
        ("icloud", "Subscriptions", "iCloud"),
        ("youtube", "Subscriptions", "YouTube"),
        ("disney", "Subscriptions", "Disney+"),
        ("crave", "Subscriptions", "Crave"),
        ("chatgpt", "Subscriptions", "ChatGPT"),
        ("openai", "Subscriptions", "OpenAI"),
        ("claude", "Subscriptions", "Claude"),
        ("anthropic", "Subscriptions", "Anthropic"),
        ("github", "Subscriptions", "GitHub"),
        ("amazon prime", "Subscriptions", "Amazon Prime"),
        ("google one", "Subscriptions", "Google One"),
        ("dropbox", "Subscriptions", "Dropbox"),
        ("adobe", "Subscriptions", "Adobe"),
        ("hulu", "Subscriptions", "Hulu"),
        ("audible", "Subscriptions", "Audible"),
        // Entertainment
        ("cineplex", "Entertainment", "Cineplex"),
        ("steam", "Entertainment", "Steam"),
        ("steamgames", "Entertainment", "Steam"),
        ("playstation", "Entertainment", "PlayStation"),
        ("nintendo", "Entertainment", "Nintendo"),
        ("xbox", "Entertainment", "Xbox"),
        ("ticketmaster", "Entertainment", "Ticketmaster"),
        // Shopping
        ("amazon", "Shopping", "Amazon"),
        ("amzn", "Shopping", "Amazon"),
        ("best buy", "Shopping", "Best Buy"),
        ("ikea", "Shopping", "IKEA"),
        ("canadian tire", "Shopping", "Canadian Tire"),
        ("dollarama", "Shopping", "Dollarama"),
        ("shoppers", "Shopping", "Shoppers Drug Mart"),
        ("home depot", "Shopping", "Home Depot"),
        ("staples", "Shopping", "Staples"),
        ("target", "Shopping", "Target"),
        ("etsy", "Shopping", "Etsy"),
        ("apple store", "Shopping", "Apple Store"),
        // Gas
        ("shell", "Gas", "Shell"),
        ("esso", "Gas", "Esso"),
        ("petro", "Gas", "Petro-Canada"),
        ("chevron", "Gas", "Chevron"),
        ("husky", "Gas", "Husky"),
        ("costco gas", "Gas", "Costco Gas"),
        ("ultramar", "Gas", "Ultramar"),
        ("circle k", "Gas", "Circle K"),
        // Fitness
        ("goodlife", "Fitness", "GoodLife Fitness"),
        ("fitness world", "Fitness", "Fitness World"),
        ("anytime fitness", "Fitness", "Anytime Fitness"),
        ("planet fitness", "Fitness", "Planet Fitness"),
        ("orangetheory", "Fitness", "Orangetheory"),
        ("ymca", "Fitness", "YMCA"),
        // Health
        ("london drugs", "Health", "London Drugs"),
        ("pharmasave", "Health", "Pharmasave"),
        ("rexall", "Health", "Rexall"),
        ("jean coutu", "Health", "Jean Coutu"),
        ("walgreens", "Health", "Walgreens"),
        ("cvs", "Health", "CVS"),
        ("lifelabs", "Health", "LifeLabs"),
        // Personal care
        ("sephora", "Personal care", "Sephora"),
        ("great clips", "Personal care", "Great Clips"),
        ("supercuts", "Personal care", "Supercuts"),
        ("bath and body works", "Personal care", "Bath & Body Works"),
        // Clothes
        ("lululemon", "Clothes", "Lululemon"),
        ("uniqlo", "Clothes", "Uniqlo"),
        ("zara", "Clothes", "Zara"),
        ("h&m", "Clothes", "H&M"),
        ("aritzia", "Clothes", "Aritzia"),
        ("nike", "Clothes", "Nike"),
        ("adidas", "Clothes", "Adidas"),
        ("old navy", "Clothes", "Old Navy"),
        ("winners", "Clothes", "Winners"),
        ("sport chek", "Clothes", "Sport Chek"),
        // Travel
        ("air canada", "Travel", "Air Canada"),
        ("westjet", "Travel", "WestJet"),
        ("airbnb", "Travel", "Airbnb"),
        ("expedia", "Travel", "Expedia"),
        ("booking.com", "Travel", "Booking.com"),
        ("hotels.com", "Travel", "Hotels.com"),
        ("flair airlines", "Travel", "Flair Airlines"),
        ("porter airlines", "Travel", "Porter Airlines"),
        ("marriott", "Travel", "Marriott"),
        ("vrbo", "Travel", "Vrbo"),
        // Going out
        ("bc liquor", "Going out", "BC Liquor"),
        ("lcbo", "Going out", "LCBO"),
        ("cactus club", "Going out", "Cactus Club"),
        ("the keg", "Going out", "The Keg"),
    ]

    /// Starter rules (Starbucks → Coffee, Uber → Transportation …) mapped onto the seeded categories by name.
    /// Rules whose target category name isn't present are skipped.
    public static func builtInRules(categories: [Category]) -> [MerchantRule] {
        func id(_ name: String) -> UUID? { categories.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.id }
        return builtInSeeds.compactMap { pattern, category, display in
            guard let categoryID = id(category) else { return nil }
            let normalized = normalize(pattern)
            guard !normalized.isEmpty else { return nil }
            return MerchantRule(pattern: normalized, categoryID: categoryID, displayName: display, isUserDefined: false)
        }
    }
}
