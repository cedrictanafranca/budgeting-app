import SwiftUI
import BudgetCore

/// Account drill-down: balance, its transactions, edit, and "Record payment" for credit cards.
struct AccountDetailView: View {
    @Bindable var store: BudgetStore
    var accountID: UUID

    @State private var showingEditor = false
    @State private var showingPayment = false
    @State private var editingTransaction: BudgetTransaction?

    private var account: Account? { store.account(id: accountID) }

    var body: some View {
        Group {
            if let account {
                content(account)
            } else {
                EmptyState(title: "Account not found", message: "It may have been removed.")
            }
        }
        .screenBackground()
        .inlineNavigationTitle(account?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let account { AccountEditor(store: store, account: account) }
        }
        .sheet(isPresented: $showingPayment) {
            if let account { RecordPaymentSheet(store: store, card: account) }
        }
        .sheet(item: $editingTransaction) { transaction in
            NavigationStack {
                TransactionDetailsView(store: store, mode: .edit(transaction)) { editingTransaction = nil }
            }
        }
    }

    private func content(_ account: Account) -> some View {
        let transactions = store.transactions.filter { $0.accountID == account.id || $0.transferToAccountID == account.id }
        let balance = store.calculator.balance(for: account, transactions: store.transactions)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Layout.cardSpacing) {
                Card(elevated: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            AccountIconTile(account: account, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.type.title)
                                    .font(Theme.Fonts.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                Text(DateFormatting.updatedLabel(store.calculator.lastActivity(for: account, transactions: store.transactions) ?? account.openingDate, calendar: store.calendar))
                                    .font(Theme.Fonts.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                        Text(account.type.isLiability ? "Balance owed" : "Balance")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text(balance.display)
                            .font(.system(size: 34, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .contentTransition(.numericText())
                        if let card = account.cardIdentifier, !card.isEmpty {
                            Label("Wallet card: \(card)", systemImage: "wave.3.right")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }

                if account.type == .creditCard {
                    PrimaryButton(title: "Record payment", color: Theme.Colors.accent) { showingPayment = true }
                }

                SectionLabel("Transactions", prominent: true)
                if transactions.isEmpty {
                    EmptyState(title: "No transactions", message: "Activity on this account will appear here.")
                } else {
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(transactions) { transaction in
                                Button { editingTransaction = transaction } label: {
                                    HStack(spacing: 0) {
                                        TransactionRow(transaction: transaction, store: store)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                                if transaction.id != transactions.last?.id {
                                    Divider().overlay(Theme.Colors.separator).padding(.leading, 64)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(.horizontal, Theme.Layout.screenPadding)
            .padding(.bottom, 24)
        }
    }
}

/// Credit-card payment = transfer from a bank account into the card (never counts as spending).
struct RecordPaymentSheet: View {
    @Bindable var store: BudgetStore
    var card: Account

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var fromAccountID: UUID?
    @State private var date = Date()
    @State private var errorMessage: String?

    private var sourceAccounts: [Account] { store.activeAccounts.filter { $0.type != .creditCard } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    let owed = store.calculator.balance(for: card, transactions: store.transactions)
                    Text("Current balance owed: \(owed.display)")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 8)
                    FieldRow(title: "Amount") {
                        TextField("0.00", text: $amountText)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .decimalKeyboard()
                            .monospacedDigit()
                    }
                    FieldRow(title: "From") {
                        Picker("From", selection: $fromAccountID) {
                            Text("Choose").tag(UUID?.none)
                            ForEach(sourceAccounts) { Text($0.name).tag(UUID?.some($0.id)) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    FieldRow(title: "Date") {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    if owed.amount > 0 {
                        Button("Pay full balance (\(owed.display))") {
                            amountText = NSDecimalNumber(decimal: owed.rounded.amount).stringValue
                        }
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.accent)
                        .buttonStyle(.plain)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.negative)
                    }
                    PrimaryButton(title: "Record payment") { save() }
                        .padding(.top, 8)
                }
                .padding(.horizontal, Theme.Layout.screenPadding)
            }
            .screenBackground()
            .inlineNavigationTitle("Pay \(card.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                if fromAccountID == nil {
                    fromAccountID = (sourceAccounts.first { $0.isDefaultForExpenses } ?? sourceAccounts.first)?.id
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let money = Money(string: amountText, currency: store.settings.currencyCode), money.amount > 0 else {
            errorMessage = BudgetError.invalidAmount.errorDescription
            return
        }
        guard let fromAccountID else {
            errorMessage = "Choose the account the payment comes from."
            return
        }
        let transaction = BudgetTransaction(
            kind: .transfer,
            amount: money.rounded,
            merchant: "Payment to \(card.name)",
            date: date,
            accountID: fromAccountID,
            transferToAccountID: card.id
        )
        do {
            try store.add(transaction)
            Haptics.success()
            dismiss()
        } catch {
            Haptics.error()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#if os(iOS)
#Preview {
    let store = BudgetStore.preview()
    return NavigationStack {
        AccountDetailView(store: store, accountID: store.accounts.first { $0.type == .creditCard }?.id ?? UUID())
    }
}
#endif
