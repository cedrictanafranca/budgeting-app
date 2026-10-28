import AppIntents
import BudgetCore
import Foundation

/// "Log Expense" — the action the Wallet *Transaction* automation (and the manual shortcut) calls.
/// Runs in the app's process without opening the UI; see docs/ARCHITECTURE.md §5 and
/// docs/SHORTCUTS_SETUP.md.
public struct LogExpenseIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Expense"
    public static let description = IntentDescription(
        "Logs a purchase in Budget. Use it in a Wallet transaction automation to record Apple Pay purchases automatically, or on its own to log cash spending. The category is picked from your merchant rules unless you choose one.",
        categoryName: "Transactions",
        searchKeywords: ["expense", "budget", "apple pay", "wallet", "spend", "purchase"]
    )
    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = true

    @Parameter(
        title: "Merchant",
        description: "Where the money was spent, e.g. the Merchant from the Wallet transaction.",
        requestValueDialog: "Where did you spend it?"
    )
    public var merchant: String

    @Parameter(
        title: "Amount",
        description: "Amount spent, e.g. 6.45.",
        requestValueDialog: "How much did you spend?"
    )
    public var amount: Double

    @Parameter(
        title: "Currency",
        description: "3-letter currency code like CAD. Leave empty to use your Budget currency."
    )
    public var currency: String?

    @Parameter(
        title: "Card",
        description: "Card name from the Wallet transaction. Matched to the account whose Card identifier or name contains it."
    )
    public var card: String?

    @Parameter(
        title: "Category",
        description: "Leave empty to let Budget pick the category from the merchant."
    )
    public var category: CategoryEntity?

    @Parameter(
        title: "Date",
        description: "When the purchase happened. Leave empty for now."
    )
    public var date: Date?

    @Parameter(title: "Note", description: "Optional note saved with the transaction.")
    public var note: String?

    @Parameter(
        title: "Type",
        description: "Expense for purchases. Choose Income to log a refund.",
        default: .expense
    )
    public var kind: TransactionKindAppEnum

    @Dependency private var store: BudgetStore

    public init() {}

    public static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) at \(\.$merchant)") {
            \.$currency
            \.$card
            \.$category
            \.$date
            \.$note
            \.$kind
        }
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<TransactionEntity> {
        // Pick up anything written since the store was loaded (cheap; keeps dedupe accurate).
        store.reload()

        let request = try makeRequest(settingsCurrency: store.settings.currencyCode)

        let outcome: LogOutcome
        do {
            outcome = try store.logExternal(request)
        } catch let error as BudgetError {
            throw LogExpenseError(error)
        } catch {
            throw LogExpenseError.saveFailed(error.localizedDescription)
        }

        let transaction = outcome.transaction
        let entity = TransactionEntity(transaction, store: store)
        let message = Self.dialogText(for: outcome, categoryName: store.category(id: transaction.categoryID)?.name)
        return .result(value: entity, dialog: IntentDialog(stringLiteral: message))
    }

    /// Validates the raw Shortcuts input and turns it into a store request.
    func makeRequest(settingsCurrency: String) throws -> ExternalExpenseRequest {
        let merchantName = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !merchantName.isEmpty else { throw LogExpenseError.missingMerchant }

        guard amount.isFinite, amount != 0 else { throw LogExpenseError.invalidAmount(amount) }

        let currencyCode = try Self.currencyCode(from: currency, fallback: settingsCurrency)
        let money = Money(double: abs(amount), currency: currencyCode)
        guard money.amount > 0 else { throw LogExpenseError.invalidAmount(amount) }

        // A negative amount on an expense is a refund: log it as income.
        var transactionKind = kind.kind
        if amount < 0, transactionKind == .expense { transactionKind = .income }

        let cardName = card?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ExternalExpenseRequest(
            merchant: merchantName,
            amount: money,
            kind: transactionKind,
            date: date ?? Date(),
            cardIdentifier: (cardName?.isEmpty ?? true) ? nil : cardName,
            categoryID: category?.id,
            note: note,
            source: .shortcut,
            paymentMetadata: nil
        )
    }

    static func currencyCode(from raw: String?, fallback: String) throws -> String {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return fallback }
        let code = trimmed.uppercased()
        guard code.count == 3, code.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            throw LogExpenseError.invalidCurrency(trimmed)
        }
        return code
    }

    /// "Logged CA$6.45 at Starbucks → Coffee shops" / "Already logged CA$6.45 at Starbucks (skipped)".
    static func dialogText(for outcome: LogOutcome, categoryName: String?) -> String {
        let transaction = outcome.transaction
        let amountText = transaction.amount.formatted()
        switch outcome {
        case .duplicate:
            return "Already logged \(amountText) at \(transaction.merchant) (skipped)"
        case .created:
            let prefix = transaction.kind == .income ? "Logged refund of" : "Logged"
            if let categoryName {
                return "\(prefix) \(amountText) at \(transaction.merchant) → \(categoryName)"
            }
            return "\(prefix) \(amountText) at \(transaction.merchant)"
        }
    }
}
