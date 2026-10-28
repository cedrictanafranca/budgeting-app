import Foundation

/// Prevents the same purchase being logged twice (Shortcuts automation re-runs, manual + automatic entry, etc.).
public struct DuplicateDetector: Sendable {
    /// Two transactions with the same merchant and amount within this window are considered the same purchase.
    public var window: TimeInterval

    public init(window: TimeInterval = 10 * 60) {
        self.window = window
    }

    /// Stable fingerprint for an externally sourced transaction: normalized merchant + amount + 5-minute time bucket.
    public static func fingerprint(merchant: String, amount: Money, date: Date) -> String {
        // TODO(core-agent): tests
        let bucket = Int(date.timeIntervalSince1970 / 300)
        return "\(CategorizationEngine.normalize(merchant))|\(amount.rounded.amount)|\(bucket)"
    }

    /// Returns the existing transaction that `candidate` duplicates, if any.
    /// Match if fingerprints are equal, OR merchant (normalized) + amount match within `window`.
    public func existingDuplicate(of candidate: Transaction, in existing: [Transaction]) -> Transaction? {
        // TODO(core-agent): implement + tests
        if let fingerprint = candidate.externalFingerprint,
           let match = existing.first(where: { $0.externalFingerprint == fingerprint }) {
            return match
        }
        let normalized = CategorizationEngine.normalize(candidate.merchant)
        return existing.first { other in
            other.id != candidate.id
                && other.amount.rounded == candidate.amount.rounded
                && CategorizationEngine.normalize(other.merchant) == normalized
                && abs(other.date.timeIntervalSince(candidate.date)) <= window
        }
    }
}
