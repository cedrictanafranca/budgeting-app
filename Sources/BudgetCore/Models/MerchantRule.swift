import Foundation

/// Deterministic merchant → category mapping. User overrides are stored as rules with
/// `isUserDefined == true` and always win over built-in rules.
public struct MerchantRule: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    /// Normalized pattern (lowercased, punctuation stripped). Matched as a substring of the
    /// normalized merchant string, longest pattern wins.
    public var pattern: String
    public var categoryID: UUID
    /// Optional cleaned-up display name to apply, e.g. "SQ *BLUE BOTTLE" → "Blue Bottle".
    public var displayName: String?
    public var isUserDefined: Bool
    public var hitCount: Int
    public var lastUsed: Date?

    public init(
        id: UUID = UUID(),
        pattern: String,
        categoryID: UUID,
        displayName: String? = nil,
        isUserDefined: Bool = false,
        hitCount: Int = 0,
        lastUsed: Date? = nil
    ) {
        self.id = id
        self.pattern = pattern
        self.categoryID = categoryID
        self.displayName = displayName
        self.isUserDefined = isUserDefined
        self.hitCount = hitCount
        self.lastUsed = lastUsed
    }
}
