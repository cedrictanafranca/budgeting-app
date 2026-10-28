import AppIntents
import BudgetCore

/// `TransactionKind` exposed to Shortcuts. Automations can pass *Income* for refunds.
public enum TransactionKindAppEnum: String, AppEnum {
    case expense
    case income
    case transfer

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Transaction Type"

    public static let caseDisplayRepresentations: [TransactionKindAppEnum: DisplayRepresentation] = [
        .expense: "Expense",
        .income: "Income (refund)",
        .transfer: "Transfer",
    ]

    public var kind: TransactionKind {
        switch self {
        case .expense: return .expense
        case .income: return .income
        case .transfer: return .transfer
        }
    }

    public init(_ kind: TransactionKind) {
        switch kind {
        case .expense: self = .expense
        case .income: self = .income
        case .transfer: self = .transfer
        }
    }
}
