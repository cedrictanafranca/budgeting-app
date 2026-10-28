import Foundation
import BudgetCore

// Record <-> struct conversion. Unknown raw values (e.g. from a newer build) fall back to a
// safe default instead of failing the whole load.

// MARK: - Transaction

extension TransactionRecord {
    convenience init(_ value: BudgetCore.Transaction) {
        self.init(
            id: value.id,
            kindRaw: value.kind.rawValue,
            amount: value.amount.amount,
            currencyCode: value.amount.currencyCode,
            merchant: value.merchant,
            note: value.note,
            date: value.date,
            categoryID: value.categoryID,
            accountID: value.accountID,
            transferToAccountID: value.transferToAccountID,
            sourceRaw: value.source.rawValue,
            externalFingerprint: value.externalFingerprint,
            paymentMetadata: value.paymentMetadata,
            recurringRuleID: value.recurringRuleID,
            createdAt: value.createdAt,
            updatedAt: value.updatedAt
        )
    }

    func update(from value: BudgetCore.Transaction) {
        kindRaw = value.kind.rawValue
        amount = value.amount.amount
        currencyCode = value.amount.currencyCode
        merchant = value.merchant
        note = value.note
        date = value.date
        categoryID = value.categoryID
        accountID = value.accountID
        transferToAccountID = value.transferToAccountID
        sourceRaw = value.source.rawValue
        externalFingerprint = value.externalFingerprint
        paymentMetadata = value.paymentMetadata
        recurringRuleID = value.recurringRuleID
        createdAt = value.createdAt
        updatedAt = value.updatedAt
    }

    var domain: BudgetCore.Transaction {
        BudgetCore.Transaction(
            id: id,
            kind: BudgetCore.TransactionKind(rawValue: kindRaw) ?? .expense,
            amount: Money(amount, currency: currencyCode),
            merchant: merchant,
            note: note,
            date: date,
            categoryID: categoryID,
            accountID: accountID,
            transferToAccountID: transferToAccountID,
            source: BudgetCore.TransactionSource(rawValue: sourceRaw) ?? .manual,
            externalFingerprint: externalFingerprint,
            paymentMetadata: paymentMetadata,
            recurringRuleID: recurringRuleID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Category

extension CategoryRecord {
    convenience init(_ value: BudgetCore.Category) {
        self.init(
            id: value.id,
            name: value.name,
            emoji: value.emoji,
            colorHex: value.colorHex,
            periodRaw: value.period.rawValue,
            budgetAmount: value.budget?.amount,
            budgetCurrencyCode: value.budget?.currencyCode,
            sortOrder: value.sortOrder,
            isArchived: value.isArchived
        )
    }

    func update(from value: BudgetCore.Category) {
        name = value.name
        emoji = value.emoji
        colorHex = value.colorHex
        periodRaw = value.period.rawValue
        budgetAmount = value.budget?.amount
        budgetCurrencyCode = value.budget?.currencyCode
        sortOrder = value.sortOrder
        isArchived = value.isArchived
    }

    var domain: BudgetCore.Category {
        BudgetCore.Category(
            id: id,
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            period: BudgetCore.BudgetPeriod(rawValue: periodRaw) ?? .monthly,
            budget: budgetAmount.map { Money($0, currency: budgetCurrencyCode ?? Money.defaultCurrency) },
            sortOrder: sortOrder,
            isArchived: isArchived
        )
    }
}

// MARK: - Account

extension AccountRecord {
    convenience init(_ value: BudgetCore.Account) {
        self.init(
            id: value.id,
            name: value.name,
            typeRaw: value.type.rawValue,
            openingBalanceAmount: value.openingBalance.amount,
            openingBalanceCurrencyCode: value.openingBalance.currencyCode,
            openingDate: value.openingDate,
            colorHex: value.colorHex,
            sortOrder: value.sortOrder,
            isArchived: value.isArchived,
            cardIdentifier: value.cardIdentifier,
            isDefaultForExpenses: value.isDefaultForExpenses
        )
    }

    func update(from value: BudgetCore.Account) {
        name = value.name
        typeRaw = value.type.rawValue
        openingBalanceAmount = value.openingBalance.amount
        openingBalanceCurrencyCode = value.openingBalance.currencyCode
        openingDate = value.openingDate
        colorHex = value.colorHex
        sortOrder = value.sortOrder
        isArchived = value.isArchived
        cardIdentifier = value.cardIdentifier
        isDefaultForExpenses = value.isDefaultForExpenses
    }

    var domain: BudgetCore.Account {
        BudgetCore.Account(
            id: id,
            name: name,
            type: BudgetCore.AccountType(rawValue: typeRaw) ?? .chequing,
            openingBalance: Money(openingBalanceAmount, currency: openingBalanceCurrencyCode),
            openingDate: openingDate,
            colorHex: colorHex,
            sortOrder: sortOrder,
            isArchived: isArchived,
            cardIdentifier: cardIdentifier,
            isDefaultForExpenses: isDefaultForExpenses
        )
    }
}

// MARK: - Merchant rule

extension MerchantRuleRecord {
    convenience init(_ value: BudgetCore.MerchantRule) {
        self.init(
            id: value.id,
            pattern: value.pattern,
            categoryID: value.categoryID,
            displayName: value.displayName,
            isUserDefined: value.isUserDefined,
            hitCount: value.hitCount,
            lastUsed: value.lastUsed
        )
    }

    func update(from value: BudgetCore.MerchantRule) {
        pattern = value.pattern
        categoryID = value.categoryID
        displayName = value.displayName
        isUserDefined = value.isUserDefined
        hitCount = value.hitCount
        lastUsed = value.lastUsed
    }

    var domain: BudgetCore.MerchantRule {
        BudgetCore.MerchantRule(
            id: id,
            pattern: pattern,
            categoryID: categoryID,
            displayName: displayName,
            isUserDefined: isUserDefined,
            hitCount: hitCount,
            lastUsed: lastUsed
        )
    }
}

// MARK: - Recurring rule

extension RecurringRuleRecord {
    convenience init(_ value: BudgetCore.RecurringRule) {
        self.init(
            id: value.id,
            merchant: value.merchant,
            amount: value.amount.amount,
            currencyCode: value.amount.currencyCode,
            kindRaw: value.kind.rawValue,
            categoryID: value.categoryID,
            accountID: value.accountID,
            note: value.note,
            frequencyRaw: value.frequency.rawValue,
            interval: value.interval,
            startDate: value.startDate,
            endDate: value.endDate,
            isPaused: value.isPaused,
            generatedPeriodKeys: value.generatedPeriodKeys
        )
    }

    func update(from value: BudgetCore.RecurringRule) {
        merchant = value.merchant
        amount = value.amount.amount
        currencyCode = value.amount.currencyCode
        kindRaw = value.kind.rawValue
        categoryID = value.categoryID
        accountID = value.accountID
        note = value.note
        frequencyRaw = value.frequency.rawValue
        interval = value.interval
        startDate = value.startDate
        endDate = value.endDate
        isPaused = value.isPaused
        generatedPeriodKeys = value.generatedPeriodKeys
    }

    var domain: BudgetCore.RecurringRule {
        BudgetCore.RecurringRule(
            id: id,
            merchant: merchant,
            amount: Money(amount, currency: currencyCode),
            kind: BudgetCore.TransactionKind(rawValue: kindRaw) ?? .expense,
            categoryID: categoryID,
            accountID: accountID,
            note: note,
            frequency: BudgetCore.RecurrenceFrequency(rawValue: frequencyRaw) ?? .monthly,
            interval: interval,
            startDate: startDate,
            endDate: endDate,
            isPaused: isPaused,
            generatedPeriodKeys: generatedPeriodKeys
        )
    }
}

// MARK: - Settings

extension SettingsRecord {
    convenience init(_ value: BudgetCore.BudgetSettings) {
        self.init(
            key: BudgetPersistence.settingsKey,
            currencyCode: value.currencyCode,
            weekStartsOn: value.weekStartsOn,
            monthlyIncomeTargetAmount: value.monthlyIncomeTarget?.amount,
            monthlyIncomeTargetCurrencyCode: value.monthlyIncomeTarget?.currencyCode,
            userName: value.userName,
            hasCompletedOnboarding: value.hasCompletedOnboarding
        )
    }

    func update(from value: BudgetCore.BudgetSettings) {
        currencyCode = value.currencyCode
        weekStartsOn = value.weekStartsOn
        monthlyIncomeTargetAmount = value.monthlyIncomeTarget?.amount
        monthlyIncomeTargetCurrencyCode = value.monthlyIncomeTarget?.currencyCode
        userName = value.userName
        hasCompletedOnboarding = value.hasCompletedOnboarding
    }

    var domain: BudgetCore.BudgetSettings {
        BudgetCore.BudgetSettings(
            currencyCode: currencyCode,
            weekStartsOn: weekStartsOn,
            monthlyIncomeTarget: monthlyIncomeTargetAmount.map { Money($0, currency: monthlyIncomeTargetCurrencyCode ?? currencyCode) },
            userName: userName,
            hasCompletedOnboarding: hasCompletedOnboarding
        )
    }
}
