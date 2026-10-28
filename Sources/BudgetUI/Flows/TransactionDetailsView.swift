import SwiftUI
import BudgetCore

/// Step 2 of quick add, and the editor for existing transactions.
struct TransactionDetailsView: View {
    enum Mode {
        case new(Money)
        case edit(BudgetTransaction)
    }

    @Bindable var store: BudgetStore
    var mode: Mode
    var onFinish: () -> Void

    @State private var kind: TransactionKind
    @State private var amountText: String
    @State private var merchant: String
    @State private var categoryID: UUID?
    @State private var userPickedCategory: Bool
    @State private var accountID: UUID?
    @State private var toAccountID: UUID?
    @State private var date: Date
    @State private var note: String
    @State private var errorMessage: String?
    @State private var confirmingDelete = false
    @FocusState private var merchantFocused: Bool

    init(store: BudgetStore, mode: Mode, onFinish: @escaping () -> Void) {
        self.store = store
        self.mode = mode
        self.onFinish = onFinish
        switch mode {
        case .new(let amount):
            _kind = State(initialValue: .expense)
            _amountText = State(initialValue: Self.plainString(amount.amount))
            _merchant = State(initialValue: "")
            _categoryID = State(initialValue: nil)
            _userPickedCategory = State(initialValue: false)
            _accountID = State(initialValue: store.defaultExpenseAccount?.id)
            _toAccountID = State(initialValue: nil)
            _date = State(initialValue: Date())
            _note = State(initialValue: "")
        case .edit(let transaction):
            _kind = State(initialValue: transaction.kind)
            _amountText = State(initialValue: Self.plainString(transaction.amount.amount))
            _merchant = State(initialValue: transaction.merchant)
            _categoryID = State(initialValue: transaction.categoryID)
            _userPickedCategory = State(initialValue: true)
            _accountID = State(initialValue: transaction.accountID)
            _toAccountID = State(initialValue: transaction.transferToAccountID)
            _date = State(initialValue: transaction.date)
            _note = State(initialValue: transaction.note ?? "")
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var currency: String { store.settings.currencyCode }

    private var suggestions: [MerchantSuggestion] {
        guard kind != .transfer else { return [] }
        let trimmed = merchant.trimmingCharacters(in: .whitespaces)
        return store.categorizer.merchantSuggestions(matching: trimmed)
            .filter { $0.name.caseInsensitiveCompare(trimmed) != .orderedSame }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                amountHeader

                Picker("Type", selection: $kind.animation(Theme.springAnimation)) {
                    ForEach(TransactionKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                merchantField

                if !suggestions.isEmpty {
                    suggestionChips
                }

                if kind == .expense {
                    SectionLabel("Category")
                    categoryGrid
                }

                SectionLabel("Details")
                VStack(spacing: 8) {
                    accountRow(title: kind == .transfer ? "From" : "Account", selection: $accountID)
                    if kind == .transfer {
                        accountRow(title: "To", selection: $toAccountID)
                    }
                    FieldRow(title: "Date") {
                        DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    FieldRow(title: "Note") {
                        TextField("Optional", text: $note, axis: .vertical)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .lineLimit(1...3)
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.negative)
                        .transition(.opacity)
                }

                PrimaryButton(title: isEditing ? "Save changes" : "Save") { save() }
                    .padding(.top, 6)

                if isEditing {
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Text("Delete transaction")
                            .font(Theme.Fonts.body)
                            .foregroundStyle(Theme.Colors.negative)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Layout.screenPadding)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .inlineNavigationTitle(isEditing ? "Edit Transaction" : "Details")
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onFinish)
                }
            }
        }
        .onAppear {
            if !isEditing {
                // Defer so the push animation finishes before the keyboard appears.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { merchantFocused = true }
            }
        }
        .onChange(of: merchant) { _, newValue in
            suggestCategory(for: newValue)
        }
        .onChange(of: kind) { _, newKind in
            errorMessage = nil
            if newKind == .transfer, toAccountID == nil {
                toAccountID = store.activeAccounts.first { $0.id != accountID }?.id
            }
        }
        .confirmationDialog("Delete this transaction?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        }
    }

    // MARK: Sections

    private var amountHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(Money.symbolPrefix(for: currency))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
            TextField("0", text: $amountText)
                .font(.system(size: 40, weight: .semibold))
                .monospacedDigit()
                .textFieldStyle(.plain)
                .decimalKeyboard()
                .fixedSize()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var merchantField: some View {
        HStack(spacing: 10) {
            Image(systemName: kind == .income ? "arrow.down.circle" : "storefront")
                .foregroundStyle(Theme.Colors.textSecondary)
            TextField(kind == .income ? "Source (e.g. Paycheque)" : kind == .transfer ? "Description (optional)" : "Merchant", text: $merchant)
                .font(Theme.Fonts.body)
                .textFieldStyle(.plain)
                .focused($merchantFocused)
                .wordsCapitalization()
                .submitLabel(.done)
                .onSubmit { merchantFocused = false }
            if !merchant.isEmpty {
                Button { merchant = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear merchant")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.Colors.card))
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    Button {
                        Haptics.selection()
                        merchant = suggestion.name
                        if let id = suggestion.categoryID {
                            categoryID = id
                            userPickedCategory = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let category = store.category(id: suggestion.categoryID) {
                                Text(category.emoji).font(.system(size: 13))
                            }
                            Text(suggestion.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.Colors.pillNeutral))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 12) {
            ForEach(store.activeCategories) { category in
                let selected = categoryID == category.id
                Button {
                    Haptics.selection()
                    withAnimation(Theme.springAnimation) {
                        categoryID = selected ? nil : category.id
                        userPickedCategory = true
                    }
                } label: {
                    VStack(spacing: 6) {
                        CategoryCircle(category: category, size: 44)
                            .overlay(
                                Circle()
                                    .strokeBorder(Theme.Colors.accent, lineWidth: 2.5)
                                    .padding(-4)
                                    .opacity(selected ? 1 : 0)
                            )
                            .scaleEffect(selected ? 1.05 : 1)
                        Text(category.name)
                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(category.name)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func accountRow(title: String, selection: Binding<UUID?>) -> some View {
        FieldRow(title: title) {
            Menu {
                Picker(title, selection: selection) {
                    Text("None").tag(UUID?.none)
                    ForEach(store.activeAccounts) { account in
                        Text(account.name).tag(UUID?.some(account.id))
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(store.account(id: selection.wrappedValue)?.name ?? "Choose")
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Theme.Colors.accent)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: Actions

    private func suggestCategory(for merchant: String) {
        guard kind == .expense, !userPickedCategory else { return }
        let trimmed = merchant.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { categoryID = nil; return }
        let suggested = store.categorizer.suggest(merchant: trimmed)?.categoryID
        if suggested != categoryID {
            withAnimation(Theme.springAnimation) { categoryID = suggested }
        }
    }

    private func save() {
        errorMessage = nil
        guard let money = Money(string: amountText, currency: currency), money.amount > 0 else {
            fail(BudgetError.invalidAmount.errorDescription)
            return
        }
        var name = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if kind == .transfer {
            guard let from = accountID, let to = toAccountID else { fail("Choose both accounts for a transfer."); return }
            guard from != to else { fail("Choose two different accounts."); return }
            if name.isEmpty { name = "Transfer to \(store.account(id: to)?.name ?? "account")" }
        }
        guard !name.isEmpty else { fail(BudgetError.missingMerchant.errorDescription); return }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var transaction: BudgetTransaction
        switch mode {
        case .new:
            transaction = BudgetTransaction(kind: kind, amount: money.rounded, merchant: name)
        case .edit(let existing):
            transaction = existing
        }
        transaction.kind = kind
        transaction.amount = money.rounded
        transaction.merchant = name
        transaction.note = trimmedNote.isEmpty ? nil : trimmedNote
        transaction.date = date
        transaction.categoryID = kind == .expense ? categoryID : (kind == .income ? transaction.categoryID : nil)
        transaction.accountID = accountID
        transaction.transferToAccountID = kind == .transfer ? toAccountID : nil

        do {
            if isEditing {
                try store.update(transaction)
            } else {
                try store.add(transaction)
            }
            Haptics.success()
            onFinish()
        } catch {
            fail((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func delete() {
        guard case .edit(let transaction) = mode else { return }
        do {
            try store.deleteTransaction(id: transaction.id)
            Haptics.success()
            onFinish()
        } catch {
            fail((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func fail(_ message: String?) {
        Haptics.error()
        withAnimation { errorMessage = message ?? "Something went wrong." }
    }

    private static func plainString(_ value: Decimal) -> String {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .bankers)
        return NSDecimalNumber(decimal: rounded).stringValue
    }
}

#if os(iOS)
#Preview("New") {
    NavigationStack {
        TransactionDetailsView(store: .preview(), mode: .new(Money(12.5)), onFinish: {})
    }
}

#Preview("Edit") {
    let store = BudgetStore.preview()
    return NavigationStack {
        TransactionDetailsView(store: store, mode: .edit(store.transactions[0]), onFinish: {})
    }
}
#endif
