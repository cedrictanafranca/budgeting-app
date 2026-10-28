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
        let bucket = Int((date.timeIntervalSince1970 / 300).rounded(.down))
        return "\(CategorizationEngine.normalize(merchant))|\(amount.rounded.amount)|\(bucket)"
    }

    /// Returns the existing transaction that `candidate` duplicates, if any.
    /// Match if fingerprints are equal, OR merchant (normalized) + amount match within `window`.
    /// A transaction never duplicates itself (same id is ignored).
    public func existingDuplicate(of candidate: Transaction, in existing: [Transaction]) -> Transaction? {
        let others = existing.filter { $0.id != candidate.id }

        if let fingerprint = candidate.externalFingerprint,
           let match = others.first(where: { $0.externalFingerprint == fingerprint }) {
            return match
        }

        let normalized = CategorizationEngine.normalize(candidate.merchant)
        let amount = candidate.amount.rounded
        return others
            .filter { other in
                other.kind == candidate.kind
                    && other.amount.rounded == amount
                    && abs(other.date.timeIntervalSince(candidate.date)) <= window
                    && CategorizationEngine.normalize(other.merchant) == normalized
            }
            .min { abs($0.date.timeIntervalSince(candidate.date)) < abs($1.date.timeIntervalSince(candidate.date)) }
    }
}
