import Foundation

public enum AccountType: String, Codable, Sendable, CaseIterable, Identifiable {
    case chequing, savings, creditCard, cash
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .chequing: return "Chequing"
        case .savings: return "Savings"
        case .creditCard: return "Credit Card"
        case .cash: return "Cash"
        }
    }
    /// Luna groups accounts into "Bank Accounts" and "Credit Cards".
    public var groupTitle: String { self == .creditCard ? "Credit Cards" : "Bank Accounts" }
    /// Credit cards track a balance owed; spending increases it, payments (transfers in) reduce it.
    public var isLiability: Bool { self == .creditCard }
}

public struct Account: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var type: AccountType
    /// Balance at the moment the account was added; transactions after `openingDate` adjust it.
    public var openingBalance: Money
    public var openingDate: Date
    public var colorHex: String
    public var sortOrder: Int
    public var isArchived: Bool
    /// Optional identifier used to map a Wallet card from Shortcuts to this account
    /// (e.g. "Visa ••••1234" or the card's display name). Matched case-insensitively by substring.
    public var cardIdentifier: String?
    public var isDefaultForExpenses: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        openingBalance: Money = .zero(),
        openingDate: Date = Date(),
        colorHex: String = "#5B3DF5",
        sortOrder: Int = 0,
        isArchived: Bool = false,
        cardIdentifier: String? = nil,
        isDefaultForExpenses: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.openingBalance = openingBalance
        self.openingDate = openingDate
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.cardIdentifier = cardIdentifier
        self.isDefaultForExpenses = isDefaultForExpenses
    }
}
