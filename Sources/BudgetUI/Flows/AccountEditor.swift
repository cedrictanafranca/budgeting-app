import SwiftUI
import BudgetCore

/// Create or edit an account: name, type, opening balance, Wallet card mapping, default toggle.
struct AccountEditor: View {
    @Bindable var store: BudgetStore
    var account: Account?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var type: AccountType
    @State private var balanceText: String
    @State private var openingDate: Date
    @State private var cardIdentifier: String
    @State private var isDefault: Bool
    @State private var colorHex: String
    @State private var errorMessage: String?
    @State private var confirmingArchive = false

    init(store: BudgetStore, account: Account?) {
        self.store = store
        self.account = account
        _name = State(initialValue: account?.name ?? "")
        _type = State(initialValue: account?.type ?? .chequing)
        _balanceText = State(initialValue: account.map { NSDecimalNumber(decimal: $0.openingBalance.amount).stringValue } ?? "")
        _openingDate = State(initialValue: account?.openingDate ?? Date())
        _cardIdentifier = State(initialValue: account?.cardIdentifier ?? "")
        _isDefault = State(initialValue: account?.isDefaultForExpenses ?? false)
        _colorHex = State(initialValue: account?.colorHex ?? "#2563EB")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Spacer()
                        AccountIconTile(account: Account(name: name, type: type, colorHex: colorHex), size: 56)
                            .animation(Theme.springAnimation, value: type)
                        Spacer()
                    }
                    .padding(.vertical, 12)

                    FieldRow(title: "Name") {
                        TextField("RBC Chequing", text: $name)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .wordsCapitalization()
                    }
                    FieldRow(title: "Type") {
                        Picker("Type", selection: $type) {
                            ForEach(AccountType.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    FieldRow(title: type.isLiability ? "Opening balance owed" : "Opening balance") {
                        TextField("0.00", text: $balanceText)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .decimalKeyboard()
                            .monospacedDigit()
                    }
                    FieldRow(title: "As of") {
                        DatePicker("As of", selection: $openingDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    SectionLabel("Apple Pay").padding(.top, 6)
                    FieldRow(title: "Wallet card") {
                        TextField("e.g. Visa ••1234", text: $cardIdentifier)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                    }
                    Text("Matched against the card name Shortcuts passes in, so Apple Pay purchases land in this account.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, 4)
                    FieldRow(title: "Default for expenses") {
                        Toggle("Default for expenses", isOn: $isDefault)
                            .labelsHidden()
                            .tint(Theme.Colors.accent)
                    }

                    SectionLabel("Color").padding(.top, 6)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Theme.categoryPalette, id: \.self) { hex in
                                Button { colorHex = hex } label: {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(hex: hex))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(Color(hex: hex), lineWidth: 2)
                                                .padding(-4)
                                                .opacity(colorHex == hex ? 1 : 0)
                                        )
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Color \(hex)")
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.negative)
                    }

                    if account != nil {
                        Button(role: .destructive) { confirmingArchive = true } label: {
                            Text("Archive account")
                                .font(Theme.Fonts.body)
                                .foregroundStyle(Theme.Colors.negative)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, Theme.Layout.screenPadding)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .inlineNavigationTitle(account == nil ? "New Account" : "Edit Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Archive this account?", isPresented: $confirmingArchive, titleVisibility: .visible) {
                Button("Archive", role: .destructive) { archive() }
            } message: {
                Text("It will be hidden from Accounts; its transactions stay in your history.")
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Enter a name."; return }
        let currency = store.settings.currencyCode
        let balanceInput = balanceText.trimmingCharacters(in: .whitespaces)
        let opening: Money
        if balanceInput.isEmpty {
            opening = .zero(currency)
        } else if let parsed = Money(string: balanceInput, currency: currency) {
            opening = parsed.rounded
        } else {
            errorMessage = "Enter a valid opening balance."
            return
        }
        var updated = account ?? Account(name: trimmed, type: type, sortOrder: (store.accounts.map(\.sortOrder).max() ?? -1) + 1)
        updated.name = trimmed
        updated.type = type
        updated.openingBalance = opening
        updated.openingDate = openingDate
        updated.colorHex = colorHex
        let card = cardIdentifier.trimmingCharacters(in: .whitespaces)
        updated.cardIdentifier = card.isEmpty ? nil : card
        updated.isDefaultForExpenses = isDefault
        do {
            // Only one default expense account at a time.
            if isDefault {
                for var other in store.accounts where other.id != updated.id && other.isDefaultForExpenses {
                    other.isDefaultForExpenses = false
                    try store.save(other)
                }
            }
            try store.save(updated)
            Haptics.success()
            dismiss()
        } catch {
            Haptics.error()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func archive() {
        guard var account else { return }
        account.isArchived = true
        account.isDefaultForExpenses = false
        do {
            try store.save(account)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#if os(iOS)
#Preview {
    AccountEditor(store: .preview(), account: nil)
}
#endif
