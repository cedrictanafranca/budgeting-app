import Foundation
import CheckKit
import BudgetCore

func categorizationChecks() {
    typealias F = CoreFixtures
    let categories = DefaultData.categories()
    func id(_ name: String) -> UUID { categories.first { $0.name == name }!.id }
    let builtIn = CategorizationEngine.builtInRules(categories: categories)
    func engine(rules: [MerchantRule] = builtIn, history: [Transaction] = []) -> CategorizationEngine {
        CategorizationEngine(rules: rules, categories: categories, history: history)
    }

    suite("CategorizationEngine.normalize") {
        check("strips store numbers, processor prefixes and punctuation") {
            expectEqual(CategorizationEngine.normalize("Starbucks #2231"), "starbucks")
            expectEqual(CategorizationEngine.normalize("SQ *BLUE BOTTLE COFFEE"), "blue bottle coffee")
            expectEqual(CategorizationEngine.normalize("SQ*BLUE BOTTLE"), "blue bottle")
            expectEqual(CategorizationEngine.normalize("TST* Cafe Medina"), "cafe medina")
            expectEqual(CategorizationEngine.normalize("TST *Cafe Medina"), "cafe medina")
            expectEqual(CategorizationEngine.normalize("PAYPAL *SPOTIFY"), "spotify")
            expectEqual(CategorizationEngine.normalize("PP*Steam Games"), "steam games")
            expectEqual(CategorizationEngine.normalize("SP GYMSHARK"), "gymshark")
            expectEqual(CategorizationEngine.normalize("UBER *TRIP HELP.UBER.COM"), "uber trip help uber com")
            expectEqual(CategorizationEngine.normalize("IGA store 55"), "iga")
            expectEqual(CategorizationEngine.normalize("Tim Hortons 1234"), "tim hortons")
            expectEqual(CategorizationEngine.normalize("McDonald's #4412"), "mcdonalds")
            expectEqual(CategorizationEngine.normalize("A&W #101"), "a w")
            expectEqual(CategorizationEngine.normalize("A & W"), "a w")
            expectEqual(CategorizationEngine.normalize("T&T Supermarket"), "t t supermarket")
            expectEqual(CategorizationEngine.normalize("  Safeway   (Cambie)  "), "safeway cambie")
            expectEqual(CategorizationEngine.normalize("Café Crème"), "cafe creme")
        }
        check("marketplace prefixes keep the meaningful part") {
            expectEqual(CategorizationEngine.normalize("AMZN MKTP CA*2K3XY9"), "amazon")
            expectEqual(CategorizationEngine.normalize("AMZN Mktp US"), "amazon")
            expectEqual(CategorizationEngine.normalize("APPLE.COM/BILL 866-712-7753"), "apple bill")
        }
        check("is idempotent and safe on odd input") {
            for raw in ["SQ *BLUE BOTTLE #12", "Starbucks", "UBER *TRIP HELP.UBER.COM", "H&M", "", "   ", "1234", "#", "***"] {
                let once = CategorizationEngine.normalize(raw)
                expectEqual(CategorizationEngine.normalize(once), once, "idempotent for \(raw)")
            }
            expectEqual(CategorizationEngine.normalize(""), "")
            expectEqual(CategorizationEngine.normalize("1234"), "1234")   // never strip the only token
        }
        check("cleanDisplayName title-cases and keeps short acronyms") {
            expectEqual(CategorizationEngine.cleanDisplayName("SQ *BLUE BOTTLE #12"), "Blue Bottle")
            expectEqual(CategorizationEngine.cleanDisplayName("IGA #5521"), "IGA")
            expectEqual(CategorizationEngine.cleanDisplayName("STARBUCKS #2231"), "Starbucks")
            expectEqual(CategorizationEngine.cleanDisplayName("starbucks"), "Starbucks")
            expectEqual(CategorizationEngine.cleanDisplayName("A&W"), "A&W")
            expectEqual(CategorizationEngine.cleanDisplayName("h&m"), "H&M")
            expectEqual(CategorizationEngine.cleanDisplayName("McDonald's"), "McDonald's")
            expectEqual(CategorizationEngine.cleanDisplayName("SAVE ON FOODS"), "Save On Foods")
            expectEqual(CategorizationEngine.cleanDisplayName("KFC"), "KFC")
            expectEqual(CategorizationEngine.cleanDisplayName("  "), "")
        }
    }

    suite("CategorizationEngine.suggest") {
        check("built-in merchants map to seeded categories") {
            let cases: [(String, String)] = [
                ("STARBUCKS #2231", "Coffee shops"), ("Tim Hortons #0412", "Coffee shops"), ("SQ *BLUE BOTTLE COFFEE", "Coffee shops"),
                ("MCDONALD'S #12", "Eating out"), ("A&W 0412", "Eating out"), ("DOORDASH*CHIPOTLE", "Eating out"), ("UBER *EATS HELP.UBER.COM", "Eating out"),
                ("WALMART SUPERCENTRE #3011", "Groceries"), ("COSTCO WHOLESALE W123", "Groceries"), ("SAVE ON FOODS #6591", "Groceries"), ("IGA Marketplace", "Groceries"), ("T&T SUPERMARKET", "Groceries"),
                ("UBER *TRIP HELP.UBER.COM", "Ubers/Lyft"), ("LYFT *RIDE", "Ubers/Lyft"),
                ("TRANSLINK COMPASS", "Transportation"), ("GO TRANSIT", "Transportation"),
                ("NETFLIX.COM", "Subscriptions"), ("SPOTIFY P3A1", "Subscriptions"), ("APPLE.COM/BILL", "Subscriptions"), ("ANTHROPIC", "Subscriptions"), ("CLAUDE.AI SUBSCRIPTION", "Subscriptions"), ("GITHUB, INC.", "Subscriptions"),
                ("CINEPLEX #1234", "Entertainment"), ("STEAMGAMES.COM", "Entertainment"),
                ("AMAZON.CA", "Shopping"), ("AMZN MKTP CA*1B2C3", "Shopping"), ("BEST BUY #977", "Shopping"), ("CANADIAN TIRE #123", "Shopping"), ("SHOPPERS DRUG MART #1", "Shopping"),
                ("SHELL C12345", "Gas"), ("PETRO-CANADA", "Gas"), ("COSTCO GAS #123", "Gas"),
                ("GOODLIFE CLUBS", "Fitness"), ("ANYTIME FITNESS", "Fitness"),
                ("LONDON DRUGS #75", "Health"), ("REXALL #1", "Health"),
                ("LULULEMON ATHLETICA", "Clothes"), ("H&M 0023", "Clothes"), ("H&M CANADA", "Clothes"), ("A&W RESTAURANTS", "Eating out"), ("ARITZIA", "Clothes"),
                ("AIR CANADA 0142", "Travel"), ("WESTJET", "Travel"), ("AIRBNB * HM123", "Travel"), ("BOOKING.COM", "Travel"),
            ]
            for (merchant, expected) in cases {
                let suggestion = engine().suggest(merchant: merchant)
                expectEqual(suggestion?.categoryID, id(expected), "\(merchant) → \(expected)")
                expectEqual(suggestion?.reason, .builtInRule, merchant)
                expectEqual(suggestion?.confidence, 0.8, merchant)
            }
        }
        check("whole-word matching avoids false positives") {
            // "iga" must not hit "tigard"; "evo" must not hit "devoted".
            expect(engine().suggest(merchant: "Tigard Hardware")?.reason != .builtInRule)
            expect(engine().suggest(merchant: "Devoted Pet Care")?.reason != .builtInRule)
        }
        check("user rules beat built-in rules, exact beats substring, longest wins") {
            let coffeeUser = MerchantRule(pattern: "starbucks", categoryID: id("Eating out"), displayName: "Sbux", isUserDefined: true)
            let s1 = engine(rules: builtIn + [coffeeUser]).suggest(merchant: "STARBUCKS #1")
            expectEqual(s1?.categoryID, id("Eating out"))
            expectEqual(s1?.reason, .userRule)
            expectEqual(s1?.confidence, 1.0)
            expectEqual(s1?.displayName, "Sbux")

            let short = MerchantRule(pattern: "star", categoryID: id("Gifts"), isUserDefined: true)
            let long = MerchantRule(pattern: "starbucks reserve", categoryID: id("Going out"), isUserDefined: true)
            let exact = MerchantRule(pattern: "starbucks reserve roastery", categoryID: id("Travel"), isUserDefined: true)
            // Longest substring among user rules.
            expectEqual(engine(rules: builtIn + [short, long]).suggest(merchant: "Starbucks Reserve Seattle")?.categoryID, id("Going out"))
            // Exact beats longer substring.
            expectEqual(engine(rules: builtIn + [exact, MerchantRule(pattern: "starbucks", categoryID: id("Gifts"), isUserDefined: true)]).suggest(merchant: "Starbucks")?.categoryID, id("Gifts"))
            // Built-in exact vs longest built-in substring.
            expectEqual(engine().suggest(merchant: "Uber Eats")?.categoryID, id("Eating out"))
            expectEqual(engine().suggest(merchant: "Uber")?.categoryID, id("Ubers/Lyft"))
        }
        check("patterns shorter than 3 characters only match exactly") {
            let tiny = MerchantRule(pattern: "ab", categoryID: id("Gifts"), isUserDefined: true)
            expectEqual(engine(rules: [tiny]).suggest(merchant: "Lab Coffee")?.reason, .fallback)
            expectEqual(engine(rules: [tiny]).suggest(merchant: "AB")?.categoryID, id("Gifts"))
            let tinyBuiltIn = MerchantRule(pattern: "ab", categoryID: id("Gifts"), isUserDefined: false)
            expectEqual(engine(rules: [tinyBuiltIn]).suggest(merchant: "ab lunch")?.reason, .fallback)
        }
        check("history: most frequent category, ties go to the most recent, confidence 0.7") {
            let merchant = "Joe's Diner"
            func txn(_ category: String, _ day: Int) -> Transaction {
                Transaction(amount: Money(10), merchant: merchant, date: F.date(2026, 10, day), categoryID: id(category))
            }
            let frequent = engine(history: [txn("Eating out", 1), txn("Eating out", 2), txn("Going out", 3)]).suggest(merchant: "JOE'S DINER #3")
            expectEqual(frequent?.categoryID, id("Eating out"))
            expectEqual(frequent?.reason, .history)
            expectEqual(frequent?.confidence, 0.7)
            let tie = engine(history: [txn("Eating out", 1), txn("Going out", 5)]).suggest(merchant: merchant)
            expectEqual(tie?.categoryID, id("Going out"))
            // Rules still beat history.
            let rule = MerchantRule(pattern: "joes diner", categoryID: id("Gifts"), isUserDefined: true)
            expectEqual(engine(rules: builtIn + [rule], history: [txn("Eating out", 1)]).suggest(merchant: merchant)?.reason, .userRule)
            // Different merchants don't leak into each other.
            expectEqual(engine(history: [txn("Eating out", 1)]).suggest(merchant: "Joe's Diner Downtown")?.reason, .fallback)
        }
        check("fallback is 'Other'/'Misc' with confidence 0.1, else nil") {
            let fallback = engine().suggest(merchant: "Totally Unknown Place")
            expectEqual(fallback?.reason, .fallback)
            expectEqual(fallback?.confidence, 0.1)
            expectEqual(fallback?.categoryID, id("Other"))
            let noOther = CategorizationEngine(rules: [], categories: categories.filter { $0.name != "Other" && $0.name != "Misc spending" }, history: [])
            expect(noOther.suggest(merchant: "Totally Unknown Place") == nil)
        }
    }

    suite("CategorizationEngine.builtInRules") {
        check("covers ~80+ merchants, normalized, skips missing categories") {
            expect(builtIn.count >= 80, "got \(builtIn.count)")
            expect(builtIn.allSatisfy { !$0.isUserDefined && $0.pattern == CategorizationEngine.normalize($0.pattern) && !$0.pattern.isEmpty })
            expect(Set(builtIn.map(\.categoryID)).isSubset(of: Set(categories.map(\.id))))
            let partial = CategorizationEngine.builtInRules(categories: categories.filter { $0.name == "Gas" })
            expect(!partial.isEmpty && partial.allSatisfy { $0.categoryID == id("Gas") })
            expect(CategorizationEngine.builtInRules(categories: []).isEmpty)
        }
    }

    suite("CategorizationEngine.merchantSuggestions") {
        func txn(_ merchant: String, _ amount: Decimal, _ day: Int, category: String? = nil, kind: TransactionKind = .expense) -> Transaction {
            Transaction(kind: kind, amount: Money(amount), merchant: merchant, date: F.date(2026, 10, day), categoryID: category.map(id))
        }
        let history = [
            txn("Starbucks #1", 6, 1, category: "Coffee shops"),
            txn("STARBUCKS", 7, 5, category: "Coffee shops"),
            txn("starbucks #99", 8, 9, category: "Eating out"),
            txn("Sushi Garden", 40, 7, category: "Eating out"),
            txn("Costco", 90, 8, category: "Groceries"),
            txn("Costco", 80, 3, category: "Groceries"),
            txn("Paycheque", 2000, 2, kind: .income),
            txn("Star Market", 12, 10, category: "Groceries"),
        ]
        let e = engine(history: history)
        check("empty prefix returns most-used first, then most recent") {
            let all = e.merchantSuggestions(matching: "")
            expectEqual(all.map(\.name), ["Starbucks", "Costco", "Star Market", "Sushi Garden", "Paycheque"])
            expectEqual(all.map(\.useCount), [3, 2, 1, 1, 1])
            // Limit applies.
            expectEqual(e.merchantSuggestions(matching: "", limit: 2).count, 2)
        }
        check("groups case-insensitively; category = most frequent; lastAmount = most recent") {
            let sbux = e.merchantSuggestions(matching: "starb")
            expectEqual(sbux.count, 1)
            expectEqual(sbux[0].categoryID, id("Coffee shops"))
            expectEqual(sbux[0].lastAmount?.amount, 8)
            expectEqual(sbux[0].useCount, 3)
        }
        check("starts-with ranks before contains; non-matches excluded") {
            let result = e.merchantSuggestions(matching: "st")
            // Starbucks and Star Market start with "st"; Costco merely contains it, so it ranks last despite more uses than Star Market.
            expectEqual(result.map(\.name), ["Starbucks", "Star Market", "Costco"])
            let contains = e.merchantSuggestions(matching: "ar")
            expectEqual(contains.map(\.name), ["Starbucks", "Star Market", "Sushi Garden"])
            expect(e.merchantSuggestions(matching: "zzz").isEmpty)
            expect(CategorizationEngine(rules: [], categories: categories, history: []).merchantSuggestions(matching: "").isEmpty)
            expectEqual(e.merchantSuggestions(matching: "Sushi").first?.categoryID, id("Eating out"))
            expectEqual(e.merchantSuggestions(matching: "paycheque").first?.categoryID, nil)
        }
    }
}
