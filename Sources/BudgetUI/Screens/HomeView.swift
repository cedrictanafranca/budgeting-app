import SwiftUI
import BudgetCore

struct CategoryRoute: Hashable {
    var id: UUID
}

/// Luna's Home: income row, then one card per budget period (Weekly / Monthly / Savings).
struct HomeView: View {
    @Bindable var store: BudgetStore
    @State private var showingNewCategory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Layout.cardSpacing) {
                    IncomeCard(store: store)
                    ForEach(BudgetPeriod.allCases) { period in
                        let summary = store.calculator.summary(
                            period: period,
                            categories: store.categories,
                            transactions: store.transactions,
                            currency: store.settings.currencyCode
                        )
                        PeriodCard(summary: summary, currency: store.settings.currencyCode)
                    }
                    DashedAddRow(title: "Add new category", showsIcon: false, height: 48) {
                        showingNewCategory = true
                    }
                }
                .padding(.horizontal, Theme.Layout.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .hiddenNavigationBar()
            .navigationDestination(for: CategoryRoute.self) { route in
                CategoryDetailView(store: store, categoryID: route.id)
            }
            .sheet(isPresented: $showingNewCategory) {
                CategoryEditor(store: store, category: nil)
            }
        }
    }
}

// MARK: - Income

struct IncomeCard: View {
    @Bindable var store: BudgetStore
    @State private var expanded = false
    @State private var editingTarget = false
    @State private var targetText = ""

    private var month: DateInterval { store.calculator.interval(for: .monthly, containing: Date()) }
    private var currency: String { store.settings.currencyCode }
    private var income: Money {
        store.calculator.totalIncome(transactions: store.transactions, in: month, currency: currency)
    }
    private var incomeTransactions: [BudgetTransaction] {
        store.transactions.filter { $0.kind == .income && month.contains($0.date) }
    }

    var body: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(Theme.springAnimation) { expanded.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Text("💸").font(.system(size: 18))
                        Text("Income")
                            .font(Theme.Fonts.rowTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text(income.display)
                            .font(Theme.Fonts.rowTitle)
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.positive)
                            .contentTransition(.numericText())
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    Divider().overlay(Theme.Colors.separator)
                    expandedContent
                        .padding(16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .clipped()
        .alert("Monthly income target", isPresented: $editingTarget) {
            TextField("Amount", text: $targetText)
                .decimalKeyboard()
            Button("Save") { saveTarget() }
            if store.settings.monthlyIncomeTarget != nil {
                Button("Remove target", role: .destructive) { saveTarget(remove: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Shown next to this month's income.")
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let target = store.settings.monthlyIncomeTarget, target.amount > 0 {
                let fraction = min(max(income.doubleValue / max(target.doubleValue, 0.01), 0), 1)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(income.display) of \(target.display) target")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        Pill(amount: income - target, style: income >= target ? .positive : .neutral)
                    }
                    ProgressBar(fraction: fraction, color: Theme.Colors.positive)
                }
            }

            if incomeTransactions.isEmpty {
                Text("No income recorded this month.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(incomeTransactions.prefix(5)) { transaction in
                    HStack {
                        Text(transaction.merchant)
                            .font(Theme.Fonts.rowTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text(DateFormatting.monthDay.string(from: transaction.date))
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text(transaction.amount.formatted(showsCode: false, signed: true))
                            .font(Theme.Fonts.rowTitle)
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.positive)
                    }
                }
            }

            Button(store.settings.monthlyIncomeTarget == nil ? "Set monthly target" : "Edit monthly target") {
                targetText = store.settings.monthlyIncomeTarget.map { "\($0.amount)" } ?? ""
                editingTarget = true
            }
            .font(Theme.Fonts.caption.weight(.semibold))
            .foregroundStyle(Theme.Colors.accent)
            .buttonStyle(.plain)
        }
    }

    private func saveTarget(remove: Bool = false) {
        var settings = store.settings
        if remove {
            settings.monthlyIncomeTarget = nil
        } else if let money = Money(string: targetText, currency: currency), money.amount > 0 {
            settings.monthlyIncomeTarget = money
        } else {
            return
        }
        try? store.save(settings)
    }
}

// MARK: - Period card

struct PeriodCard: View {
    var summary: PeriodSummary
    var currency: String

    private var isSavings: Bool { summary.period == .savings }
    private let budgetColumn: CGFloat = 74
    private let leftColumn: CGFloat = 72

    var body: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                Divider().overlay(Theme.Colors.separator)
                if summary.categories.isEmpty {
                    Text("No \(summary.period.title.lowercased()) categories yet.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(summary.categories) { item in
                            NavigationLink(value: CategoryRoute(id: item.category.id)) {
                                row(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.period.title)
                    .foregroundStyle(Theme.Colors.textSecondary)
                if !isSavings {
                    Text(DateFormatting.daysLeftLabel(summary.daysLeft))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
            Spacer()
            headerColumn(title: isSavings ? "Target" : "Budgeted", value: summary.budgeted, width: budgetColumn)
            headerColumn(title: isSavings ? "Funded" : "Left", value: isSavings ? summary.spent : summary.remaining, width: leftColumn)
        }
        .font(Theme.Fonts.caption)
    }

    private func headerColumn(title: String, value: Money, width: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title).foregroundStyle(Theme.Colors.textSecondary)
            Text(value.display)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(width: width, alignment: .trailing)
    }

    private func row(_ item: CategorySummary) -> some View {
        let budgeted = item.budgeted ?? .zero(currency)
        let pillAmount: Money
        let style: PillStyle
        if isSavings {
            pillAmount = item.spent
            style = .forFunded(item.spent, target: item.budgeted)
        } else {
            pillAmount = item.remaining ?? .zero(currency)
            style = .forRemaining(item.remaining)
        }
        return HStack(spacing: 10) {
            CategoryCircle(category: item.category)
            Text(item.category.name)
                .font(Theme.Fonts.rowTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)
            Spacer(minLength: 4)
            Text(budgeted.display)
                .font(Theme.Fonts.rowTitle)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: budgetColumn, alignment: .trailing)
            Pill(amount: pillAmount, style: style)
                .frame(width: leftColumn, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Thin rounded progress bar (category budgets, income target).
struct ProgressBar: View {
    var fraction: Double
    var color: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.pillNeutral)
                Capsule()
                    .fill(color)
                    .frame(width: max(proxy.size.width * min(max(fraction, 0), 1), fraction > 0 ? height : 0))
            }
        }
        .frame(height: height)
        .animation(Theme.springAnimation, value: fraction)
    }
}

#if os(iOS)
#Preview("Home") {
    HomeView(store: .preview())
}
#endif
