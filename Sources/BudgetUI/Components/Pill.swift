import SwiftUI
import BudgetCore

enum PillStyle: Equatable {
    case neutral, positive, negative

    /// Luna's "Left" column: green when money remains, red when over, grey for zero / no budget.
    static func forRemaining(_ remaining: Money?) -> PillStyle {
        guard let remaining else { return .neutral }
        if remaining.amount > 0 { return .positive }
        if remaining.amount < 0 { return .negative }
        return .neutral
    }

    /// Savings "Funded" column: neutral without a target, green once reached, red while short.
    static func forFunded(_ funded: Money, target: Money?) -> PillStyle {
        guard let target, target.amount > 0 else { return .neutral }
        return funded >= target ? .positive : .negative
    }

    var background: Color {
        switch self {
        case .neutral: return Theme.Colors.pillNeutral
        case .positive: return Theme.Colors.pillPositive
        case .negative: return Theme.Colors.pillNegative
        }
    }

    var foreground: Color {
        switch self {
        case .neutral: return Theme.Colors.textSecondary
        case .positive: return Theme.Colors.positive
        case .negative: return Theme.Colors.negative
        }
    }
}

/// Rounded money pill ("$70.00" on green, "$0.00" on grey).
struct Pill: View {
    var amount: Money
    var style: PillStyle
    var minWidth: CGFloat = 64

    var body: some View {
        Text(amount.display)
            .font(Theme.Fonts.pill)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(style.foreground)
            .contentTransition(.numericText())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minWidth: minWidth)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.pillRadius, style: .continuous)
                    .fill(style.background)
            )
            .animation(Theme.springAnimation, value: amount)
            .animation(Theme.springAnimation, value: style)
    }
}

extension Money {
    /// "$12.50" — the list style in the Luna screenshots (code shown only on the amount entry screen).
    var display: String { formatted(showsCode: false) }
}

#if os(iOS)
#Preview {
    HStack {
        Pill(amount: Money(0), style: .neutral)
        Pill(amount: Money(70), style: .positive)
        Pill(amount: Money(-12.5), style: .negative)
    }
    .padding()
}
#endif
