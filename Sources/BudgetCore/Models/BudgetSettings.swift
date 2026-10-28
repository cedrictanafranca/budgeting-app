import Foundation

public struct BudgetSettings: Hashable, Codable, Sendable {
    public var currencyCode: String
    /// 1 = Sunday … 7 = Saturday (Calendar.firstWeekday semantics).
    public var weekStartsOn: Int
    /// Expected monthly income shown in the Income row; nil hides the target.
    public var monthlyIncomeTarget: Money?
    public var userName: String
    public var hasCompletedOnboarding: Bool

    public init(
        currencyCode: String = Money.defaultCurrency,
        weekStartsOn: Int = 1,
        monthlyIncomeTarget: Money? = nil,
        userName: String = "",
        hasCompletedOnboarding: Bool = false
    ) {
        self.currencyCode = currencyCode
        self.weekStartsOn = weekStartsOn
        self.monthlyIncomeTarget = monthlyIncomeTarget
        self.userName = userName
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

/// Everything the app needs in memory. Repositories load/save this; the store owns a copy.
public struct BudgetSnapshot: Hashable, Codable, Sendable {
    public var transactions: [Transaction]
    public var categories: [Category]
    public var accounts: [Account]
    public var merchantRules: [MerchantRule]
    public var recurringRules: [RecurringRule]
    public var settings: BudgetSettings

    public init(
        transactions: [Transaction] = [],
        categories: [Category] = [],
        accounts: [Account] = [],
        merchantRules: [MerchantRule] = [],
        recurringRules: [RecurringRule] = [],
        settings: BudgetSettings = BudgetSettings()
    ) {
        self.transactions = transactions
        self.categories = categories
        self.accounts = accounts
        self.merchantRules = merchantRules
        self.recurringRules = recurringRules
        self.settings = settings
    }

    public static let empty = BudgetSnapshot()
}
