import AppIntents
import BudgetCore
import Foundation

/// User-facing errors shown by Shortcuts when Log Expense cannot save. Nothing is silently dropped:
/// a failing automation shows one of these messages and can be re-run manually.
public enum LogExpenseError: Error, CustomLocalizedStringResourceConvertible, LocalizedError {
    case missingMerchant
    case invalidAmount(Double)
    case invalidCurrency(String)
    case saveFailed(String)

    public init(_ error: BudgetError) {
        switch error {
        case .missingMerchant: self = .missingMerchant
        case .invalidAmount: self = .invalidAmount(0)
        case .persistenceFailed(let message): self = .saveFailed(message)
        case .duplicate, .notFound: self = .saveFailed(error.localizedDescription)
        }
    }

    public var message: String {
        switch self {
        case .missingMerchant:
            return "Budget needs a merchant name. Check that the shortcut passes the Merchant from the Wallet transaction."
        case .invalidAmount(let value):
            if value == 0 {
                return "Budget needs an amount greater than zero. If the automation passes text like \"CA$6.45\", add a \"Get Numbers from Input\" action before Log Expense."
            }
            return "\(value) isn't a valid amount. Pass a positive number like 6.45."
        case .invalidCurrency(let code):
            return "\"\(code)\" isn't a currency code. Use a 3-letter code like CAD or USD, or leave Currency empty."
        case .saveFailed(let message):
            return "Budget couldn't save this expense (\(message)). Nothing was logged — run the shortcut again or add it in the app."
        }
    }

    public var localizedStringResource: LocalizedStringResource {
        "\(message)"
    }

    public var errorDescription: String? { message }
}
