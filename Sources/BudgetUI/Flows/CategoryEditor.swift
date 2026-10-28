import SwiftUI
import BudgetCore

/// Create or edit a category: name, emoji, color, period and budget / savings target.
struct CategoryEditor: View {
    @Bindable var store: BudgetStore
    var category: BudgetCore.Category?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var emoji: String
    @State private var colorHex: String
    @State private var period: BudgetPeriod
    @State private var budgetText: String
    @State private var errorMessage: String?

    init(store: BudgetStore, category: BudgetCore.Category?, defaultPeriod: BudgetPeriod = .monthly) {
        self.store = store
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _emoji = State(initialValue: category?.emoji ?? "🏷️")
        _colorHex = State(initialValue: category?.colorHex ?? Theme.categoryPalette[13])
        _period = State(initialValue: category?.period ?? defaultPeriod)
        _budgetText = State(initialValue: category?.budget.map { NSDecimalNumber(decimal: $0.amount).stringValue } ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    VStack(spacing: 6) {
                        CategoryCircle(emoji: emoji, colorHex: colorHex, size: 64)
                            .animation(Theme.springAnimation, value: colorHex)
                        Text(name.isEmpty ? "New category" : name)
                            .font(Theme.Fonts.cardTitle)
                            .foregroundStyle(name.isEmpty ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                    }
                    .padding(.vertical, 12)

                    FieldRow(title: "Name") {
                        TextField("Coffee shops", text: $name)
                            .multilineTextAlignment(.trailing)
                            .wordsCapitalization()
                            .textFieldStyle(.plain)
                    }
                    FieldRow(title: "Emoji") {
                        TextField("☕️", text: $emoji)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .frame(maxWidth: 80)
                            .onChange(of: emoji) { _, newValue in
                                // Keep a single grapheme (the newest one typed).
                                if newValue.count > 1, let last = newValue.last { emoji = String(last) }
                            }
                    }

                    SectionLabel("Color").padding(.top, 6)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
                        ForEach(Theme.categoryPalette, id: \.self) { hex in
                            Button {
                                Haptics.selection()
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Theme.Colors.background, lineWidth: 2)
                                            .opacity(colorHex == hex ? 1 : 0)
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color(hex: hex), lineWidth: 2)
                                            .padding(-3)
                                            .opacity(colorHex == hex ? 1 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(hex)")
                            .accessibilityAddTraits(colorHex == hex ? .isSelected : [])
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.Colors.card))

                    SectionLabel("Budget").padding(.top, 6)
                    Picker("Period", selection: $period) {
                        ForEach(BudgetPeriod.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    FieldRow(title: period == .savings ? "Target" : "\(period.title) budget") {
                        TextField("0.00", text: $budgetText)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.plain)
                            .decimalKeyboard()
                            .monospacedDigit()
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.negative)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, Theme.Layout.screenPadding)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .inlineNavigationTitle(category == nil ? "New Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Enter a name."; return }
        var budget: Money?
        let budgetInput = budgetText.trimmingCharacters(in: .whitespaces)
        if !budgetInput.isEmpty {
            guard let parsed = Money(string: budgetInput, currency: store.settings.currencyCode), parsed.amount >= 0 else {
                errorMessage = "Enter a valid amount."
                return
            }
            budget = parsed.amount > 0 ? parsed.rounded : nil
        }
        var updated = category ?? BudgetCore.Category(
            name: trimmed,
            emoji: emoji,
            colorHex: colorHex,
            sortOrder: (store.categories.map(\.sortOrder).max() ?? -1) + 1
        )
        updated.name = trimmed
        updated.emoji = emoji.isEmpty ? "🏷️" : emoji
        updated.colorHex = colorHex
        updated.period = period
        updated.budget = budget
        do {
            try store.save(updated)
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
    CategoryEditor(store: .preview(), category: nil)
}
#endif
