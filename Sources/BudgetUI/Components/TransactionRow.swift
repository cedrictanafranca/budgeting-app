import SwiftUI
import BudgetCore

/// One transaction line: avatar, merchant, category caption, signed amount.
struct TransactionRow: View {
    var transaction: BudgetTransaction
    var category: BudgetCore.Category?
    var subtitle: String

    init(transaction: BudgetTransaction, store: BudgetStore) {
        self.transaction = transaction
        self.category = store.category(id: transaction.categoryID)
        switch transaction.kind {
        case .expense:
            subtitle = store.category(id: transaction.categoryID)?.name ?? "Uncategorized"
        case .income:
            subtitle = store.category(id: transaction.categoryID)?.name ?? "Income"
        case .transfer:
            let from = store.account(id: transaction.accountID)?.name ?? "?"
            let to = store.account(id: transaction.transferToAccountID)?.name ?? "?"
            subtitle = "\(from) → \(to)"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            TransactionAvatar(transaction: transaction, category: category)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(transaction.merchant)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if transaction.source == .applePay || transaction.source == .shortcut {
                        Image(systemName: "applelogo")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .accessibilityLabel("Apple Pay")
                    }
                }
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(amountText)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var amountText: String {
        switch transaction.kind {
        case .expense: return (-transaction.amount).display
        case .income: return transaction.amount.formatted(showsCode: false, signed: true)
        case .transfer: return "↔ " + transaction.amount.display
        }
    }

    private var amountColor: Color {
        switch transaction.kind {
        case .expense: return Theme.Colors.textSecondary
        case .income: return Theme.Colors.positive
        case .transfer: return Theme.Colors.textSecondary
        }
    }
}
