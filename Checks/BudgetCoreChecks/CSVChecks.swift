import Foundation
import CheckKit
import BudgetCore

func csvChecks() {
    typealias F = CoreFixtures
    let codec = CSVCodec()

    /// Compare everything the CSV carries (created/updated stamps are not exported).
    func sameContent(_ a: Transaction, _ b: Transaction) -> Bool {
        var x = a, y = b
        x.createdAt = .distantPast; y.createdAt = .distantPast
        x.updatedAt = .distantPast; y.updatedAt = .distantPast
        x.externalFingerprint = nil; y.externalFingerprint = nil
        x.paymentMetadata = nil; y.paymentMetadata = nil
        x.recurringRuleID = nil; y.recurringRuleID = nil
        return x == y
    }

    let food = Category(name: "Eating out", emoji: "🍽️", colorHex: "#111111")
    let coffee = Category(name: "Coffee, tea & more", emoji: "☕️", colorHex: "#222222")
    let chequing = Account(name: "Chequing", type: .chequing, openingDate: F.date(2020, 1, 1))
    let card = Account(name: "Visa \"Travel\"", type: .creditCard, openingDate: F.date(2020, 1, 1))

    let transactions: [Transaction] = [
        Transaction(kind: .expense, amount: Money(Decimal(string: "6.45")!), merchant: "Starbucks, Granville", note: "latte, \"extra hot\"", date: F.date(2026, 10, 1, 8, 30), categoryID: coffee.id, accountID: card.id, source: .applePay),
        Transaction(kind: .expense, amount: Money(Decimal(string: "42.1")!), merchant: "Sushi\nGarden", note: "line1\nline2\r\nline3", date: F.date(2026, 10, 2, 19, 5), categoryID: food.id, accountID: chequing.id, source: .manual),
        Transaction(kind: .income, amount: Money(2150), merchant: "Paycheque", date: F.date(2026, 10, 1, 9), accountID: chequing.id, source: .manual),
        Transaction(kind: .transfer, amount: Money(300), merchant: "Credit Card Payment", date: F.date(2026, 10, 10, 10), accountID: chequing.id, transferToAccountID: card.id, source: .manual),
        Transaction(kind: .expense, amount: Money(Decimal(string: "0.99")!, currency: "USD"), merchant: "App Store", date: F.date(2026, 10, 11), source: .shortcut),
        Transaction(kind: .expense, amount: Money(5), merchant: "é ünï côdé 日本", date: Date(timeIntervalSince1970: 1_790_000_000), source: .recurring),
    ]
    let snapshot = BudgetSnapshot(transactions: transactions, categories: [food, coffee], accounts: [chequing, card])

    suite("CSVCodec") {
        check("export has the header and RFC 4180 quoting") {
            let csv = codec.export(snapshot)
            expect(csv.hasPrefix(CSVCodec.header.joined(separator: ",") + "\n"))
            expect(csv.contains("\"Starbucks, Granville\""))
            expect(csv.contains("\"latte, \"\"extra hot\"\"\""))
            expect(csv.contains("\"Visa \"\"Travel\"\"\""))
            expect(csv.contains("\"Coffee, tea & more\""))
            expect(csv.contains("2026-10-01T08:30:00.000Z"))
            expect(csv.contains(",6.45,CAD,"))
            expect(csv.contains(",0.99,USD,"))
            expectEqual(codec.export(BudgetSnapshot()), CSVCodec.header.joined(separator: ",") + "\n")
        }
        check("export → import round trip yields equal transactions") {
            let csv = codec.export(snapshot)
            let imported = try codec.import(csv, into: BudgetSnapshot(categories: [food, coffee], accounts: [chequing, card]))
            expectEqual(imported.transactions.count, transactions.count)
            for original in transactions {
                guard let match = imported.transactions.first(where: { $0.id == original.id }) else {
                    expect(false, "missing \(original.merchant)"); continue
                }
                expect(sameContent(original, match), "mismatch for \(original.merchant): \(original) vs \(match)")
            }
            // Existing categories/accounts were matched, not duplicated.
            expectEqual(imported.categories.count, 2)
            expectEqual(imported.accounts.count, 2)
        }
        check("round trip into an empty snapshot creates categories and accounts by name") {
            let imported = try codec.import(codec.export(snapshot), into: BudgetSnapshot())
            expectEqual(imported.transactions.count, transactions.count)
            expectEqual(Set(imported.categories.map(\.name)), ["Eating out", "Coffee, tea & more"])
            expectEqual(Set(imported.accounts.map(\.name)), ["Chequing", "Visa \"Travel\""])
            expect(imported.categories.allSatisfy { $0.period == .monthly && $0.emoji == "📦" && $0.colorHex == "#6B7280" })
            expect(imported.accounts.allSatisfy { $0.type == .chequing })
            // Names resolve back through the new ids.
            let payment = imported.transactions.first { $0.kind == .transfer }!
            expectEqual(imported.accounts.first { $0.id == payment.accountID }?.name, "Chequing")
            expectEqual(imported.accounts.first { $0.id == payment.transferToAccountID }?.name, "Visa \"Travel\"")
            // New accounts open early enough that imported rows count toward their balance.
            let calc = F.calculator()
            let imp = imported.accounts.first { $0.name == "Chequing" }!
            expectEqual(calc.balance(for: imp, transactions: imported.transactions).amount, Decimal(string: "2150")! - Decimal(string: "42.1")! - 300)
        }
        check("rows whose id already exists are skipped; re-import is a no-op") {
            let csv = codec.export(snapshot)
            let once = try codec.import(csv, into: snapshot)
            expectEqual(once.transactions.count, transactions.count)
            expectEqual(once.transactions, snapshot.transactions)
            let partial = BudgetSnapshot(transactions: [transactions[0]], categories: [food, coffee], accounts: [chequing, card])
            expectEqual(try codec.import(csv, into: partial).transactions.count, transactions.count)
            // Duplicate ids inside one file are only imported once.
            let row = "11111111-1111-1111-1111-111111111111,2026-10-01T10:00:00Z,expense,5,CAD,Dup,,,,,manual"
            let doubled = CSVCodec.header.joined(separator: ",") + "\n" + row + "\n" + row + "\n"
            expectEqual(try codec.import(doubled, into: BudgetSnapshot()).transactions.count, 1)
        }
        check("defaults: blank kind → expense, blank source → csvImport, blank id → new id, CRLF, BOM, date-only") {
            let csv = "\u{FEFF}date,amount,merchant,kind,source\r\n2026-10-05T10:00:00Z,12.50,Corner Store,,\r\n\r\n2026-10-06,3,Bus,income,\r\n"
            let result = try codec.import(csv, into: BudgetSnapshot(settings: BudgetSettings(currencyCode: "USD")))
            expectEqual(result.transactions.count, 2)
            expectEqual(result.transactions[0].kind, .expense)
            expectEqual(result.transactions[0].source, .csvImport)
            expectEqual(result.transactions[0].amount.currencyCode, "USD")
            expectEqual(result.transactions[0].amount.amount, Decimal(string: "12.5")!)
            expectEqual(result.transactions[1].kind, .income)
            expect(result.transactions[0].id != result.transactions[1].id)
        }
        check("columns are found by name, case-insensitively, in any order") {
            let result = try codec.import("Merchant,AMOUNT,Date,Category\nCoffee Co,4.25,2026-10-05T10:00:00Z,\"coffee, TEA & More\"\n", into: BudgetSnapshot(categories: [coffee]))
            expectEqual(result.categories.count, 1)
            expectEqual(result.transactions.first?.categoryID, coffee.id)
        }
        check("invalid rows throw a descriptive error with the row number") {
            let header = CSVCodec.header.joined(separator: ",")
            func failure(_ rows: String, file: String = #file, line: Int = #line) -> CSVError? {
                do { _ = try codec.import(header + "\n" + rows, into: BudgetSnapshot()); return nil } catch let error as CSVError { return error } catch { return nil }
            }
            let good = "22222222-2222-2222-2222-222222222222,2026-10-01T10:00:00Z,expense,5,CAD,Ok,,,,,manual\n"
            expectEqual(failure(good + "33333333-3333-3333-3333-333333333333,not-a-date,expense,5,CAD,Bad,,,,,manual\n"),
                        .invalidRow(row: 3, reason: "date \"not-a-date\" is not ISO 8601 (expected e.g. 2026-10-28T14:30:00Z)"))
            if case .invalidRow(let row, let reason)? = failure(good + good.replacingOccurrences(of: "2222", with: "4444") + ",2026-10-01T10:00:00Z,expense,abc,CAD,X,,,,,manual\n") {
                expectEqual(row, 4); expect(reason.contains("abc"))
            } else { expect(false, "expected invalidRow") }
            if case .invalidRow(let row, let reason)? = failure(",2026-10-01T10:00:00Z,expense,-5,CAD,X,,,,,manual\n") {
                expectEqual(row, 2); expect(reason.contains("negative"))
            } else { expect(false, "negative amount should throw") }
            if case .invalidRow(_, let reason)? = failure(",2026-10-01T10:00:00Z,refund,5,CAD,X,,,,,manual\n") { expect(reason.contains("kind")) } else { expect(false, "bad kind should throw") }
            if case .invalidRow(_, let reason)? = failure(",2026-10-01T10:00:00Z,expense,5,CAD,,,,,,manual\n") { expect(reason.contains("merchant")) } else { expect(false, "empty merchant should throw") }
            if case .invalidRow(_, let reason)? = failure("nope,2026-10-01T10:00:00Z,expense,5,CAD,X,,,,,manual\n") { expect(reason.contains("UUID")) } else { expect(false, "bad id should throw") }
            if case .invalidRow(_, let reason)? = failure(",2026-10-01T10:00:00Z,expense,5,CAD,X,,,,,teleport\n") { expect(reason.contains("source")) } else { expect(false, "bad source should throw") }
            expectEqual(CSVError.invalidRow(row: 7, reason: "x").errorDescription, "Row 7 is invalid: x")
        }
        check("structural errors") {
            do { _ = try codec.import("", into: BudgetSnapshot()); expect(false, "empty should throw") } catch { expectEqual(error as? CSVError, .empty) }
            do { _ = try codec.import("date,merchant\n2026-10-01,x\n", into: BudgetSnapshot()); expect(false) } catch { expectEqual(error as? CSVError, .missingColumn("amount")) }
            do {
                _ = try codec.import(CSVCodec.header.joined(separator: ",") + "\n,2026-10-01T10:00:00Z,expense,5,CAD,\"unterminated,,,,\n", into: BudgetSnapshot())
                expect(false, "unterminated quote should throw")
            } catch { if case .malformed? = error as? CSVError {} else { expect(false, "expected malformed, got \(error)") } }
            // Header only is fine.
            expect(try codec.import(CSVCodec.header.joined(separator: ",") + "\n", into: BudgetSnapshot()).transactions.isEmpty)
        }
        check("parser handles quotes, embedded newlines and blank lines") {
            let records = try CSVCodec.parse("a,\"b,\"\"c\"\"\",d\n\n\"line1\nline2\",x,\n")
            expectEqual(records.count, 2)
            expectEqual(records[0].fields, ["a", "b,\"c\"", "d"])
            expectEqual(records[1].fields, ["line1\nline2", "x", ""])
            expectEqual(records[1].row, 3)
        }
    }
}
