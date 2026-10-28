import Foundation

/// CSV export/import of transactions. Columns are stable so a file exported today imports later.
public struct CSVCodec: Sendable {
    public static let header = ["id", "date", "kind", "amount", "currency", "merchant", "category", "account", "transfer_to_account", "note", "source"]

    public init() {}

    public func export(_ snapshot: BudgetSnapshot) -> String {
        // TODO(core-agent): RFC 4180 quoting, ISO 8601 dates, tests round-trip
        return Self.header.joined(separator: ",") + "\n"
    }

    /// Parses CSV text. Categories/accounts are matched by name (case-insensitive) and created when missing.
    /// Rows whose `id` already exists in `snapshot` are skipped.
    public func `import`(_ csv: String, into snapshot: BudgetSnapshot) throws -> BudgetSnapshot {
        // TODO(core-agent)
        return snapshot
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
