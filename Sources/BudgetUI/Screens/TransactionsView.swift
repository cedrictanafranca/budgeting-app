import SwiftUI
import Charts
import BudgetCore

/// IMG_1873/1874: range navigator, daily bar chart, transactions grouped by day.
struct TransactionsView: View {
    @Bindable var store: BudgetStore
    @State private var rangeKind: RangeKind = .week
    @State private var offset = 0
    @State private var searchText = ""
    @State private var editing: BudgetTransaction?
    @State private var selectedDay: String?

    private var currency: String { store.settings.currencyCode }
    private var interval: DateInterval {
        store.calculator.interval(for: rangeKind.period, containing: Date(), offset: offset)
    }
    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Searching spans all history; otherwise the list follows the selected range.
    private var visibleTransactions: [BudgetTransaction] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            return store.transactions.filter { interval.contains($0.date) }
        }
        return store.transactions.filter { transaction in
            transaction.merchant.localizedCaseInsensitiveContains(query)
                || (transaction.note?.localizedCaseInsensitiveContains(query) ?? false)
                || (store.category(id: transaction.categoryID)?.name.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var groupedByDay: [(day: Date, items: [BudgetTransaction])] {
        let calendar = store.calendar
        let groups = Dictionary(grouping: visibleTransactions) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            (day, groups[day]!.sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !isSearching {
                    VStack(alignment: .leading, spacing: 12) {
                        RangeNavigator(
                            interval: interval,
                            kind: $rangeKind,
                            canGoForward: offset < 0,
                            onPrevious: { withAnimation(Theme.springAnimation) { offset -= 1 } },
                            onNext: { withAnimation(Theme.springAnimation) { offset = min(offset + 1, 0) } }
                        )
                        DailySpendChart(
                            totals: store.calculator.dailyTotals(transactions: store.transactions, in: interval, currency: currency),
                            interval: interval,
                            rangeKind: rangeKind,
                            calendar: store.calendar,
                            selectedDay: $selectedDay
                        )
                        .frame(height: 150)
                    }
                    .padding(.bottom, 4)
                    .listRowInsets(EdgeInsets(top: 4, leading: Theme.Layout.screenPadding, bottom: 8, trailing: Theme.Layout.screenPadding))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                if groupedByDay.isEmpty {
                    EmptyState(
                        title: isSearching ? "No matches" : "No transactions",
                        message: isSearching ? "Try a different merchant, note or category." : "Nothing logged for this \(rangeKind.title.lowercased()). Tap + to add one."
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(groupedByDay, id: \.day) { group in
                        Section {
                            ForEach(group.items) { transaction in
                                Button { editing = transaction } label: {
                                    TransactionRow(transaction: transaction, store: store)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 2, leading: Theme.Layout.screenPadding, bottom: 2, trailing: Theme.Layout.screenPadding))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(transaction)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(DateFormatting.monthDayYear.string(from: group.day))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .textCase(nil)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .largeNavigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search merchant, note or category")
            .onChange(of: rangeKind) { _, _ in
                offset = 0
                selectedDay = nil
            }
            .onChange(of: offset) { _, _ in selectedDay = nil }
            .sheet(item: $editing) { transaction in
                NavigationStack {
                    TransactionDetailsView(store: store, mode: .edit(transaction)) { editing = nil }
                }
            }
        }
    }

    private func delete(_ transaction: BudgetTransaction) {
        do {
            try store.deleteTransaction(id: transaction.id)
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }
}

/// Accent rounded bars per day, y-axis on the right with compact labels.
struct DailySpendChart: View {
    var totals: [DailyTotal]
    var interval: DateInterval
    var rangeKind: RangeKind
    var calendar: Calendar
    /// Selected bar, keyed by its axis label ("Oct 26").
    @Binding var selectedDay: String?

    private struct Bar: Identifiable {
        var day: Date
        var label: String
        var total: Money
        var id: String { label }
    }

    /// Zero-filled, one categorical slot per day so every label (incl. the last day) is drawn.
    private var bars: [Bar] {
        var byDay: [Date: Money] = [:]
        for total in totals { byDay[calendar.startOfDay(for: total.day), default: .zero(total.total.currencyCode)] += total.total }
        var result: [Bar] = []
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end && result.count < 62 {
            result.append(Bar(day: day, label: DateFormatting.monthDay.string(from: day), total: byDay[day] ?? .zero()))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    var body: some View {
        let bars = self.bars
        let labels = bars.map(\.label)
        // Every day for a week; the 4th/11th/18th/25th for a month (Luna's "Oct 4, Oct 11 …").
        let ticks = rangeKind == .week ? labels : [3, 10, 17, 24].compactMap { labels.indices.contains($0) ? labels[$0] : nil }
        let selected = bars.first { $0.label == selectedDay }

        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Day", bar.label),
                    y: .value("Spent", bar.total.doubleValue),
                    width: .ratio(rangeKind == .week ? 0.55 : 0.6)
                )
                .cornerRadius(rangeKind == .week ? 6 : 3, style: .continuous)
                .foregroundStyle(Theme.Colors.accent.opacity(selected == nil || selected?.label == bar.label ? 1 : 0.35))
            }
            if let selected {
                RuleMark(x: .value("Day", selected.label))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, spacing: 2, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        ChartCallout(title: selected.label, value: selected.total.display)
                    }
            }
        }
        .chartXScale(domain: labels)
        .chartXSelection(value: $selectedDay)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.Colors.gridLine)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(Money(double: amount).compact())
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: ticks) { _ in
                AxisValueLabel(collisionResolution: .disabled)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .animation(Theme.springAnimation, value: totals)
    }
}

/// Small floating label for chart selections.
struct ChartCallout: View {
    var title: String
    var value: String
    var color: Color = Theme.Colors.textPrimary

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.Colors.cardElevated)
                .shadow(color: Theme.Colors.shadow, radius: 6, x: 0, y: 2)
        )
    }
}

#if os(iOS)
#Preview {
    TransactionsView(store: .preview())
}
#endif
