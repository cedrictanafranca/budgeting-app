import SwiftUI
import BudgetCore

/// Two-step quick add: amount keypad → details. Presented full-screen from the "+" button.
struct AddTransactionFlow: View {
    @Bindable var store: BudgetStore
    var onFinish: () -> Void

    @State private var path: [Money] = []

    var body: some View {
        NavigationStack(path: $path) {
            AmountEntryView(currency: store.settings.currencyCode, onClose: onFinish) { amount in
                path.append(amount)
            }
            .navigationDestination(for: Money.self) { amount in
                TransactionDetailsView(store: store, mode: .new(amount), onFinish: onFinish)
            }
        }
    }
}

/// Step 1 (IMG_1875): big centered amount with the currency prefix, custom keypad, green Continue.
struct AmountEntryView: View {
    var currency: String
    var onClose: () -> Void
    var onContinue: (Money) -> Void

    @State private var entry = ""

    private var amount: Decimal { AmountInput.decimal(from: entry) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 24)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Money.symbolPrefix(for: currency))
                    .font(.system(size: 30, weight: .semibold))
                Text(AmountInput.display(entry))
                    .font(Theme.Fonts.amountDisplay)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.18), value: entry)
            }
            .foregroundStyle(amount > 0 ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .padding(.horizontal, Theme.Layout.screenPadding)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Amount \(Money(amount, currency: currency).formatted())")

            Spacer(minLength: 24)

            Keypad { key in
                entry = AmountInput.apply(key, to: entry)
            }
            .padding(.horizontal, 24)

            PrimaryButton(title: "Continue", isEnabled: amount > 0) {
                onContinue(Money(amount, currency: currency))
            }
            .padding(.horizontal, Theme.Layout.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .screenBackground()
        .hiddenNavigationBar()
    }
}

#if os(iOS)
#Preview("Amount entry") {
    AmountEntryView(currency: "CAD", onClose: {}, onContinue: { _ in })
}

#Preview("Add flow") {
    AddTransactionFlow(store: .preview(), onFinish: {})
}
#endif
