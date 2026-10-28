import SwiftUI
import BudgetCore

/// Category drill-down: budget progress for the current period, its transactions, edit / archive.
struct CategoryDetailView: View {
    @Bindable var store: BudgetStore
    var categoryID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var showingEditor = false
    @State private var confirmingArchive = false
    @State private var editingTransaction: BudgetTransaction?

    private var category: BudgetCore.Category? { store.category(id: categoryID) }
    private var currency: String { store.settings.currencyCode }

    var body: some View {
        Group {
            if let category {
                content(category)
            } else {
                EmptyState(title: "Category not found", message: "It may have been deleted.")
            }
        }
        .screenBackground()
        .inlineNavigationTitle(category?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showingEditor = true } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: category?.isArchived == true ? nil : .destructive) {
                        confirmingArchive = true
                    } label: {
                        Label(category?.isArchived == true ? "Unarchive" : "Archive", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Category actions")
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let category { CategoryEditor(store: store, category: category) }
        }
        .sheet(item: $editingTransaction) { transaction in
            NavigationStack {
                TransactionDetailsView(store: store, mode: .edit(transaction)) { editingTransaction = nil }
            }
        }
        .confirmationDialog(
            category?.isArchived == true ? "Unarchive this category?" : "Archive this category?",
            isPresented: $confirmingArchive,
            titleVisibility: .visible
        ) {
            Button(category?.isArchived == true ? "Unarchive" : "Archive", role: category?.isArchived == true ? nil : .destructive) {
                toggleArchive()
            }
        } message: {
            Text("Archived categories are hidden from Home but keep their transaction history.")
        }
    }

    private func content(_ category: BudgetCore.Category) -> some View {
        let summary = store.calculator.summary(period: category.period, categories: store.categories, transactions: store.transactions, currency: currency)
        let item = summary.categories.first { $0.id == category.id }
        let transactions = store.transactions.filter {
            $0.categoryID == category.id && summary.interval.contains($0.date)
        }
        return ScrollView {
            VStack(spacing: Theme.Layout.cardSpacing) {
                VStack(spacing: 8) {
                    CategoryCircle(category: category, size: 64)
                    Text(category.name)
                        .font(Theme.Fonts.screenTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(category.period == .savings ? "Savings goal" : "\(category.period.title) budget · \(DateFormatting.daysLeftLabel(summary.daysLeft))")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if category.isArchived {
                        Text("Archived")
                            .font(Theme.Fonts.pill)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Theme.Colors.pillNeutral))
                    }
                }
                .padding(.top, 8)

                progressCard(category: category, item: item)

                Card(padding: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(category.period == .savings ? "All contributions" : "This \(category.period == .weekly ? "week" : "month")")
                            .font(Theme.Fonts.cardTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(16)
                        if transactions.isEmpty {
                            EmptyState(title: "No transactions", message: "Nothing logged in this category for the period.")
                        } else {
                            ForEach(transactions) { transaction in
                                Button { editingTransaction = transaction } label: {
                                    HStack {
                                        TransactionRow(transaction: transaction, store: store)
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                                if transaction.id != transactions.last?.id {
                                    Divider().overlay(Theme.Colors.separator).padding(.leading, 64)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Layout.screenPadding)
            .padding(.bottom, 24)
        }
    }

    private func progressCard(category: BudgetCore.Category, item: CategorySummary?) -> some View {
        let spent = item?.spent ?? .zero(currency)
        let budget = category.budget
        let progress = item?.progress ?? 0
        let isSavings = category.period == .savings
        let color: Color = {
            if isSavings { return Theme.Colors.positive }
            if progress > 1 { return Theme.Colors.negative }
            return Theme.Colors.accent
        }()
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isSavings ? "Funded" : "Spent")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text(spent.display)
                            .font(Theme.Fonts.balance)
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(isSavings ? "Target" : "Budget")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text(budget?.display ?? "Not set")
                            .font(Theme.Fonts.cardTitle)
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                }
                if budget != nil {
                    ProgressBar(fraction: progress, color: color)
                    HStack {
                        Text("\(Int((progress * 100).rounded()))% \(isSavings ? "funded" : "used")")
                        Spacer()
                        if let remaining = item?.remaining {
                            Text(remaining.amount >= 0 ? "\(remaining.display) left" : "\((-remaining).display) over")
                                .foregroundStyle(remaining.amount >= 0 ? Theme.Colors.textSecondary : Theme.Colors.negative)
                        }
                    }
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                } else {
                    Button("Set a \(isSavings ? "target" : "budget")") { showingEditor = true }
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.accent)
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleArchive() {
        guard var category else { return }
        category.isArchived.toggle()
        let archived = category.isArchived
        do {
            try store.save(category)
            if archived { dismiss() }
        } catch {
            Haptics.error()
        }
    }
}

#if os(iOS)
#Preview {
    let store = BudgetStore.preview()
    return NavigationStack {
        CategoryDetailView(store: store, categoryID: store.categories.first { $0.name == "Coffee shops" }?.id ?? UUID())
    }
}
#endif
