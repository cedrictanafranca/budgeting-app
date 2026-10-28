import Foundation
import SwiftData

// SwiftData mirrors of the BudgetCore structs (1:1). Money is stored as `Decimal` + currency code,
// enums as their raw `String`. Conversion lives in RecordMapping.swift. Keep property names stable:
// renaming one is a schema migration.

@Model
public final class TransactionRecord {
    @Attribute(.unique) public var id: UUID
    public var kindRaw: String
    public var amount: Decimal
    public var currencyCode: String
    public var merchant: String
    public var note: String?
    public var date: Date
    public var categoryID: UUID?
    public var accountID: UUID?
    public var transferToAccountID: UUID?
    public var sourceRaw: String
    public var externalFingerprint: String?
    public var paymentMetadata: String?
    public var recurringRuleID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        kindRaw: String,
        amount: Decimal,
        currencyCode: String,
        merchant: String,
        note: String?,
        date: Date,
        categoryID: UUID?,
        accountID: UUID?,
        transferToAccountID: UUID?,
        sourceRaw: String,
        externalFingerprint: String?,
        paymentMetadata: String?,
        recurringRuleID: UUID?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.amount = amount
        self.currencyCode = currencyCode
        self.merchant = merchant
        self.note = note
        self.date = date
        self.categoryID = categoryID
        self.accountID = accountID
        self.transferToAccountID = transferToAccountID
        self.sourceRaw = sourceRaw
        self.externalFingerprint = externalFingerprint
        self.paymentMetadata = paymentMetadata
        self.recurringRuleID = recurringRuleID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class CategoryRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var emoji: String
    public var colorHex: String
    public var periodRaw: String
    public var budgetAmount: Decimal?
    public var budgetCurrencyCode: String?
    public var sortOrder: Int
    public var isArchived: Bool

    public init(
        id: UUID,
        name: String,
        emoji: String,
        colorHex: String,
        periodRaw: String,
        budgetAmount: Decimal?,
        budgetCurrencyCode: String?,
        sortOrder: Int,
        isArchived: Bool
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.periodRaw = periodRaw
        self.budgetAmount = budgetAmount
        self.budgetCurrencyCode = budgetCurrencyCode
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }
}

@Model
public final class AccountRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var typeRaw: String
    public var openingBalanceAmount: Decimal
    public var openingBalanceCurrencyCode: String
    public var openingDate: Date
    public var colorHex: String
    public var sortOrder: Int
    public var isArchived: Bool
    public var cardIdentifier: String?
    public var isDefaultForExpenses: Bool

    public init(
        id: UUID,
        name: String,
        typeRaw: String,
        openingBalanceAmount: Decimal,
        openingBalanceCurrencyCode: String,
        openingDate: Date,
        colorHex: String,
        sortOrder: Int,
        isArchived: Bool,
        cardIdentifier: String?,
        isDefaultForExpenses: Bool
    ) {
        self.id = id
        self.name = name
        self.typeRaw = typeRaw
        self.openingBalanceAmount = openingBalanceAmount
        self.openingBalanceCurrencyCode = openingBalanceCurrencyCode
        self.openingDate = openingDate
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.cardIdentifier = cardIdentifier
        self.isDefaultForExpenses = isDefaultForExpenses
    }
}

@Model
public final class MerchantRuleRecord {
    @Attribute(.unique) public var id: UUID
    public var pattern: String
    public var categoryID: UUID
    public var displayName: String?
    public var isUserDefined: Bool
    public var hitCount: Int
    public var lastUsed: Date?

    public init(
        id: UUID,
        pattern: String,
        categoryID: UUID,
        displayName: String?,
        isUserDefined: Bool,
        hitCount: Int,
        lastUsed: Date?
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

@Model
public final class RecurringRuleRecord {
    @Attribute(.unique) public var id: UUID
    public var merchant: String
    public var amount: Decimal
    public var currencyCode: String
    public var kindRaw: String
    public var categoryID: UUID?
    public var accountID: UUID?
    public var note: String?
    public var frequencyRaw: String
    public var interval: Int
    public var startDate: Date
    public var endDate: Date?
    public var isPaused: Bool
    public var generatedPeriodKeys: [String]

    public init(
        id: UUID,
        merchant: String,
        amount: Decimal,
        currencyCode: String,
        kindRaw: String,
        categoryID: UUID?,
        accountID: UUID?,
        note: String?,
        frequencyRaw: String,
        interval: Int,
        startDate: Date,
        endDate: Date?,
        isPaused: Bool,
        generatedPeriodKeys: [String]
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.currencyCode = currencyCode
        self.kindRaw = kindRaw
        self.categoryID = categoryID
        self.accountID = accountID
        self.note = note
        self.frequencyRaw = frequencyRaw
        self.interval = interval
        self.startDate = startDate
        self.endDate = endDate
        self.isPaused = isPaused
        self.generatedPeriodKeys = generatedPeriodKeys
    }
}

/// Singleton row (`key == BudgetPersistence.settingsKey`).
@Model
public final class SettingsRecord {
    @Attribute(.unique) public var key: String
    public var currencyCode: String
    public var weekStartsOn: Int
    public var monthlyIncomeTargetAmount: Decimal?
    public var monthlyIncomeTargetCurrencyCode: String?
    public var userName: String
    public var hasCompletedOnboarding: Bool

    public init(
        key: String = BudgetPersistence.settingsKey,
        currencyCode: String,
        weekStartsOn: Int,
        monthlyIncomeTargetAmount: Decimal?,
        monthlyIncomeTargetCurrencyCode: String?,
        userName: String,
        hasCompletedOnboarding: Bool
    ) {
        self.key = key
        self.currencyCode = currencyCode
        self.weekStartsOn = weekStartsOn
        self.monthlyIncomeTargetAmount = monthlyIncomeTargetAmount
        self.monthlyIncomeTargetCurrencyCode = monthlyIncomeTargetCurrencyCode
        self.userName = userName
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}
