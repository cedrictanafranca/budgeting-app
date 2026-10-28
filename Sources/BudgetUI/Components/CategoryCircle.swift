import SwiftUI
import BudgetCore

/// Colored circle with the category emoji (Luna's category avatar).
struct CategoryCircle: View {
    var emoji: String
    var colorHex: String
    var size: CGFloat = Theme.Layout.categoryCircle

    init(category: BudgetCore.Category, size: CGFloat = Theme.Layout.categoryCircle) {
        self.emoji = category.emoji
        self.colorHex = category.colorHex
        self.size = size
    }

    init(emoji: String, colorHex: String, size: CGFloat = Theme.Layout.categoryCircle) {
        self.emoji = emoji
        self.colorHex = colorHex
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay(
                Text(emoji.isEmpty ? "•" : emoji)
                    .font(.system(size: size * 0.5))
                    .minimumScaleFactor(0.5)
            )
            .accessibilityHidden(true)
    }
}

/// Avatar for a transaction row: category circle, income initial, or transfer arrows.
struct TransactionAvatar: View {
    var transaction: BudgetTransaction
    var category: BudgetCore.Category?
    var size: CGFloat = 36

    var body: some View {
        switch transaction.kind {
        case .expense:
            if let category {
                CategoryCircle(category: category, size: size)
            } else {
                initialCircle(fill: Theme.Colors.pillNeutral, foreground: Theme.Colors.textSecondary)
            }
        case .income:
            initialCircle(fill: Theme.Colors.pillPositive, foreground: Theme.Colors.positive)
        case .transfer:
            Circle()
                .fill(Theme.Colors.pillNeutral)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                )
        }
    }

    private func initialCircle(fill: Color, foreground: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(
                Text(String(transaction.merchant.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(foreground)
            )
    }
}

/// Rounded-square icon tile for accounts (bank / card / cash).
struct AccountIconTile: View {
    var account: Account
    var size: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Color(hex: account.colorHex))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: account.type.symbolName)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

extension AccountType {
    var symbolName: String {
        switch self {
        case .chequing: return "building.columns.fill"
        case .savings: return "banknote.fill"
        case .creditCard: return "creditcard.fill"
        case .cash: return "dollarsign.circle.fill"
        }
    }
}

#if os(iOS)
#Preview {
    HStack {
        CategoryCircle(emoji: "☕️", colorHex: "#F472B6")
        CategoryCircle(emoji: "🛒", colorHex: "#22C55E", size: 44)
    }
    .padding()
}
#endif
