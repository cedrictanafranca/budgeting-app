import Foundation

/// Errors thrown by `CSVCodec.import`. `row` is the 1-based row number in the file (the header is row 1).
public enum CSVError: Error, Equatable, LocalizedError {
    case empty
    case missingColumn(String)
    case malformed(row: Int, reason: String)
    case invalidRow(row: Int, reason: String)

    public var errorDescription: String? {
        switch self {
        case .empty: return "The CSV file is empty."
        case .missingColumn(let name): return "The CSV file has no \"\(name)\" column."
        case .malformed(let row, let reason): return "Row \(row) is malformed: \(reason)"
        case .invalidRow(let row, let reason): return "Row \(row) is invalid: \(reason)"
        }
    }
}

/// CSV export/import of transactions. Columns are stable so a file exported today imports later.
/// Not exported (so not round-tripped): fingerprint, payment metadata, recurring rule link, created/updated stamps.
public struct CSVCodec: Sendable {
    public static let header = ["id", "date", "kind", "amount", "currency", "merchant", "category", "account", "transfer_to_account", "note", "source"]

    public init() {}

    // MARK: Export

    public func export(_ snapshot: BudgetSnapshot) -> String {
        let categoryNames = Dictionary(snapshot.categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let accountNames = Dictionary(snapshot.accounts.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let formatter = Self.dateFormatter()

        var lines = [Self.header.map(Self.quote).joined(separator: ",")]
        let ordered = snapshot.transactions.sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
        for transaction in ordered {
            let fields: [String] = [
                transaction.id.uuidString,
                formatter.string(from: transaction.date),
                transaction.kind.rawValue,
                "\(transaction.amount.amount)",
                transaction.amount.currencyCode,
                transaction.merchant,
                transaction.categoryID.flatMap { categoryNames[$0] } ?? "",
                transaction.accountID.flatMap { accountNames[$0] } ?? "",
                transaction.transferToAccountID.flatMap { accountNames[$0] } ?? "",
                transaction.note ?? "",
                transaction.source.rawValue,
            ]
            lines.append(fields.map(Self.quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// RFC 4180: quote fields containing commas, quotes or line breaks (or edge whitespace); double embedded quotes.
    static func quote(_ field: String) -> String {
        let needsQuotes = field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" })
            || field.first?.isWhitespace == true || field.last?.isWhitespace == true
        guard needsQuotes else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func dateFormatter(fractional: Bool = true) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter
    }

    // MARK: Parsing

    /// Parses CSV text into records of fields. Handles quoted fields with embedded commas, quotes and
    /// newlines, CRLF / LF / CR line endings and a leading BOM. Blank lines are skipped.
    /// Each record keeps its 1-based file row number.
    public static func parse(_ text: String) throws -> [(row: Int, fields: [String])] {
        var records: [(row: Int, fields: [String])] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var fieldWasQuoted = false
        var row = 1
        var recordRow = 1

        let scalars = Array(text.unicodeScalars.drop(while: { $0 == "\u{FEFF}" }))
        var index = 0

        func endField() {
            fields.append(field)
            field = ""
            fieldWasQuoted = false
        }
        func endRecord() {
            endField()
            let isBlank = fields.count == 1 && fields[0].trimmingCharacters(in: .whitespaces).isEmpty
            if !isBlank { records.append((recordRow, fields)) }
            fields = []
        }

        while index < scalars.count {
            let c = scalars[index]
            if inQuotes {
                if c == "\"" {
                    if index + 1 < scalars.count, scalars[index + 1] == "\"" {
                        field.unicodeScalars.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    if c == "\n" { row += 1 }
                    field.unicodeScalars.append(c)
                }
            } else {
                switch c {
                case "\"":
                    if field.isEmpty && !fieldWasQuoted {
                        inQuotes = true
                        fieldWasQuoted = true
                    } else {
                        throw CSVError.malformed(row: row, reason: "unexpected quote inside an unquoted field")
                    }
                case ",":
                    endField()
                case "\n", "\r":
                    if c == "\r", index + 1 < scalars.count, scalars[index + 1] == "\n" { index += 1 }
                    endRecord()
                    row += 1
                    recordRow = row
                default:
                    if fieldWasQuoted, !(c == " " || c == "\t") {
                        throw CSVError.malformed(row: row, reason: "text after a closing quote")
                    }
                    if !fieldWasQuoted { field.unicodeScalars.append(c) }
                }
            }
            index += 1
        }
        if inQuotes { throw CSVError.malformed(row: recordRow, reason: "unterminated quoted field") }
        if !field.isEmpty || !fields.isEmpty || fieldWasQuoted { endRecord() }
        return records
    }

    // MARK: Import

    /// Parses CSV text. Categories/accounts are matched by name (case-insensitive) and created when missing.
    /// Rows whose `id` already exists in `snapshot` (or earlier in the file) are skipped.
    /// Columns are located by header name, so reordered or extra columns are fine; `date`, `amount` and
    /// `merchant` are required. Blank `kind` / `source` default to expense / csvImport.
    public func `import`(_ csv: String, into snapshot: BudgetSnapshot) throws -> BudgetSnapshot {
        let records = try Self.parse(csv)
        guard let headerRecord = records.first else { throw CSVError.empty }

        var columns: [String: Int] = [:]
        for (index, name) in headerRecord.fields.enumerated() {
            let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if columns[key] == nil { columns[key] = index }
        }
        for required in ["date", "amount", "merchant"] where columns[required] == nil {
            throw CSVError.missingColumn(required)
        }

        var result = snapshot
        var knownIDs = Set(snapshot.transactions.map(\.id))
        var categoryIDs: [String: UUID] = [:]
        for category in result.categories where categoryIDs[category.name.lowercased()] == nil { categoryIDs[category.name.lowercased()] = category.id }
        var accountIDs: [String: UUID] = [:]
        for account in result.accounts where accountIDs[account.name.lowercased()] == nil { accountIDs[account.name.lowercased()] = account.id }
        var newAccountEarliest: [UUID: Date] = [:]

        let fractional = Self.dateFormatter(fractional: true)
        let plain = Self.dateFormatter(fractional: false)
        let dateOnly = DateFormatter()
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.dateFormat = "yyyy-MM-dd"

        func resolveCategory(_ name: String) -> UUID {
            let key = name.lowercased()
            if let id = categoryIDs[key] { return id }
            let category = Category(name: name, emoji: "📦", colorHex: "#6B7280", period: .monthly, budget: nil, sortOrder: (result.categories.map(\.sortOrder).max() ?? -1) + 1)
            result.categories.append(category)
            categoryIDs[key] = category.id
            return category.id
        }
        func resolveAccount(_ name: String, date: Date) -> UUID {
            let key = name.lowercased()
            if let id = accountIDs[key] {
                if let earliest = newAccountEarliest[id], date < earliest { newAccountEarliest[id] = date }
                return id
            }
            let account = Account(name: name, type: .chequing, openingDate: date, sortOrder: (result.accounts.map(\.sortOrder).max() ?? -1) + 1)
            result.accounts.append(account)
            accountIDs[key] = account.id
            newAccountEarliest[account.id] = date
            return account.id
        }

        var imported: [Transaction] = []
        for record in records.dropFirst() {
            let row = record.row
            func value(_ column: String) -> String {
                guard let index = columns[column], index < record.fields.count else { return "" }
                return record.fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            func fail(_ reason: String) -> CSVError { .invalidRow(row: row, reason: reason) }

            // id
            let idText = value("id")
            var id = UUID()
            if !idText.isEmpty {
                guard let parsed = UUID(uuidString: idText) else { throw fail("id \"\(idText)\" is not a valid UUID") }
                id = parsed
            }
            if knownIDs.contains(id) { continue }

            // date
            let dateText = value("date")
            guard !dateText.isEmpty else { throw fail("date is empty") }
            guard let date = fractional.date(from: dateText) ?? plain.date(from: dateText) ?? dateOnly.date(from: dateText) else {
                throw fail("date \"\(dateText)\" is not ISO 8601 (expected e.g. 2026-10-28T14:30:00Z)")
            }

            // kind / source
            let kindText = value("kind").lowercased()
            let kind: TransactionKind
            if kindText.isEmpty { kind = .expense } else if let parsed = TransactionKind(rawValue: kindText) { kind = parsed } else {
                throw fail("kind \"\(value("kind"))\" must be expense, income or transfer")
            }
            let sourceText = value("source")
            let source: TransactionSource
            if sourceText.isEmpty { source = .csvImport } else if let parsed = TransactionSource.allCases.first(where: { $0.rawValue.lowercased() == sourceText.lowercased() }) { source = parsed } else {
                throw fail("source \"\(sourceText)\" is not a known source")
            }

            // amount
            let amountText = value("amount")
            guard !amountText.isEmpty else { throw fail("amount is empty") }
            guard let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) else {
                throw fail("amount \"\(amountText)\" is not a number")
            }
            guard amount >= 0 else { throw fail("amount \"\(amountText)\" must not be negative (use kind to mark income)") }
            let currencyText = value("currency")
            let currency = currencyText.isEmpty ? snapshot.settings.currencyCode : currencyText.uppercased()

            // merchant
            let merchant = value("merchant")
            guard !merchant.isEmpty else { throw fail("merchant is empty") }

            let categoryName = value("category")
            let accountName = value("account")
            let transferName = value("transfer_to_account")
            let note = record.fields.indices.contains(columns["note"] ?? -1) ? record.fields[columns["note"]!] : ""

            let transaction = Transaction(
                id: id,
                kind: kind,
                amount: Money(amount, currency: currency),
                merchant: merchant,
                note: note.isEmpty ? nil : note,
                date: date,
                categoryID: categoryName.isEmpty ? nil : resolveCategory(categoryName),
                accountID: accountName.isEmpty ? nil : resolveAccount(accountName, date: date),
                transferToAccountID: transferName.isEmpty ? nil : resolveAccount(transferName, date: date),
                source: source
            )
            knownIDs.insert(id)
            imported.append(transaction)
        }

        // Accounts created by the import start at their earliest imported transaction so those rows count toward balances.
        for (id, earliest) in newAccountEarliest {
            if let index = result.accounts.firstIndex(where: { $0.id == id }) { result.accounts[index].openingDate = earliest }
        }
        result.transactions.append(contentsOf: imported)
        return result
    }
}

/// Full JSON backup of the snapshot (restore = replaceAll).
public struct BackupCodec: Sendable {
    public init() {}
    public func encode(_ snapshot: BudgetSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }
    public func decode(_ data: Data) throws -> BudgetSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BudgetSnapshot.self, from: data)
    }
}
