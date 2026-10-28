import SwiftUI
import Charts
import BudgetCore

/// IMG_1870/1871: spend vs budget, this month vs last, last 7 months, spending by category.
struct ReportsView: View {
    @Bindable var store: BudgetStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Layout.cardSpacing) {
                    SpendVsBudgetCard(store: store)
                    MonthComparisonCard(store: store)
                    MonthlySpendCard(store: store)
                    CategoryBreakdownCard(store: store)
                }
                .padding(.horizontal, Theme.Layout.screenPadding)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .largeNavigationTitle("Reports")
        }
    }
}

// MARK: - Shared chart pieces

struct ReportCard<Legend: View, Content: View>: View {
    var title: String
    @ViewBuilder var legend: Legend
    @ViewBuilder var content: Content

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(Theme.Fonts.cardTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                legend
                content
            }
        }
    }
}

struct LegendItem: View {
    var title: String
    var color: Color
    var dashed: Bool = false
    var dot: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if dot {
                Circle().fill(color).frame(width: 8, height: 8)
            } else {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 1))
                    path.addLine(to: CGPoint(x: 16, y: 1))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [3, 2] : []))
                .frame(width: 16, height: 2)
            }
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

private extension View {
    /// Trailing compact $ axis; x labels on the 4th, 11th, 18th and 25th like Luna ("Oct 4").
    func reportAxes(month: DateInterval, calendar: Calendar) -> some View {
        let ticks = [3, 10, 17, 24].compactMap { calendar.date(byAdding: .day, value: $0, to: month.start) }
        return self
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Theme.Colors.gridLine)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) { Text(Money(double: amount).compact()) }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: ticks) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
    }
}

@MainActor
private func cumulativeValue(on day: Date, in series: [DailyTotal], calendar: Calendar) -> Money? {
    // Last cumulative value at or before `day`.
    series.last { calendar.startOfDay(for: $0.day) <= calendar.startOfDay(for: day) }?.total
}

// MARK: - Monthly spend vs budget

struct SpendVsBudgetCard: View {
    var store: BudgetStore
    @State private var selectedDate: Date?

    var body: some View {
        let calendar = store.calendar
        let currency = store.settings.currencyCode
        let calculator = store.calculator
        let month = calculator.interval(for: .monthly, containing: Date())
        let cumulative = calculator.cumulativeDailySpend(transactions: store.transactions, in: month, currency: currency)
            .filter { $0.day <= Date() }
        let budget = Self.monthlyBudget(store: store, month: month)
        let lastDay = month.end.addingTimeInterval(-1)
        let latest = cumulative.last

        ReportCard(title: "Monthly Spend vs Budget") {
            HStack(spacing: 14) {
                LegendItem(title: "Spent", color: Theme.Colors.positive)
                LegendItem(title: "Budgeted (\(budget.compact()))", color: Theme.Colors.accent, dashed: true)
            }
        } content: {
            Chart {
                LineMark(x: .value("Day", month.start), y: .value("Amount", 0), series: .value("Series", "Budget"))
                    .foregroundStyle(Theme.Colors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                LineMark(x: .value("Day", lastDay), y: .value("Amount", budget.doubleValue), series: .value("Series", "Budget"))
                    .foregroundStyle(Theme.Colors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))

                ForEach(cumulative) { point in
                    LineMark(x: .value("Day", point.day), y: .value("Amount", point.total.doubleValue), series: .value("Series", "Spent"))
                        .foregroundStyle(Theme.Colors.positive)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
                if let latest, selectedDate == nil {
                    PointMark(x: .value("Day", latest.day), y: .value("Amount", latest.total.doubleValue))
                        .foregroundStyle(Theme.Colors.positive)
                        .symbolSize(30)
                        .annotation(position: .top, spacing: 4) {
                            Text(latest.total.compact())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.Colors.positive)
                        }
                }
                if let selectedDate {
                    let spent = cumulativeValue(on: selectedDate, in: cumulative, calendar: calendar) ?? .zero(currency)
                    let elapsed = selectedDate.timeIntervalSince(month.start) / max(month.duration, 1)
                    let pace = budget.doubleValue * min(max(elapsed, 0), 1)
                    RuleMark(x: .value("Selected", selectedDate, unit: .day))
                        .foregroundStyle(Theme.Colors.chartMuted)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            ChartCallout(
                                title: DateFormatting.monthDay.string(from: selectedDate),
                                value: "\(spent.display) of \(Money(double: pace).compact())",
                                color: Theme.Colors.positive
                            )
                        }
                }
            }
            .chartXScale(domain: month.start...month.end)
            .chartXSelection(value: $selectedDate)
            .reportAxes(month: month, calendar: calendar)
            .frame(height: 160)
        }
    }

    /// Monthly budgets + weekly budgets scaled to the month length.
    @MainActor
    static func monthlyBudget(store: BudgetStore, month: DateInterval) -> Money {
        let currency = store.settings.currencyCode
        let monthly = Money.sum(store.activeCategories.filter { $0.period == .monthly }.compactMap(\.budget), currency: currency)
        let weekly = Money.sum(store.activeCategories.filter { $0.period == .weekly }.compactMap(\.budget), currency: currency)
        let days = Decimal(store.calendar.range(of: .day, in: .month, for: month.start)?.count ?? 30)
        return (monthly + weekly * (days / 7)).rounded
    }
}

// MARK: - This month vs last month

struct MonthComparisonCard: View {
    var store: BudgetStore
    @State private var selectedDate: Date?

    private struct Point: Identifiable {
        var series: String
        var date: Date
        var value: Double
        var id: String { "\(series)-\(date.timeIntervalSince1970)" }
    }

    var body: some View {
        let calendar = store.calendar
        let currency = store.settings.currencyCode
        let calculator = store.calculator
        let thisMonth = calculator.interval(for: .monthly, containing: Date())
        let lastMonth = calculator.interval(for: .monthly, containing: Date(), offset: -1)
        let current = calculator.cumulativeDailySpend(transactions: store.transactions, in: thisMonth, currency: currency)
            .filter { $0.day <= Date() }
        let previous = calculator.cumulativeDailySpend(transactions: store.transactions, in: lastMonth, currency: currency)
        // Last month's days are re-plotted onto this month's dates so both lines share the x-axis.
        let shiftedPrevious: [Point] = previous.compactMap { point in
            let dayIndex = calendar.dateComponents([.day], from: lastMonth.start, to: calendar.startOfDay(for: point.day)).day ?? 0
            guard let date = calendar.date(byAdding: .day, value: dayIndex, to: thisMonth.start), date < thisMonth.end else { return nil }
            return Point(series: "Last month", date: date, value: point.total.doubleValue)
        }
        let currentPoints = current.map { Point(series: "This month", date: $0.day, value: $0.total.doubleValue) }

        ReportCard(title: "This Month vs Last Month") {
            HStack(spacing: 14) {
                LegendItem(title: "This month", color: Theme.Colors.accent, dot: true)
                LegendItem(title: "Last month", color: Theme.Colors.chartMuted, dot: true)
            }
        } content: {
            Chart {
                ForEach(shiftedPrevious) { point in
                    LineMark(x: .value("Day", point.date), y: .value("Amount", point.value), series: .value("Series", point.series))
                        .foregroundStyle(Theme.Colors.chartMuted)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
                ForEach(currentPoints) { point in
                    LineMark(x: .value("Day", point.date), y: .value("Amount", point.value), series: .value("Series", point.series))
                        .foregroundStyle(Theme.Colors.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
                if currentPoints.isEmpty && shiftedPrevious.isEmpty {
                    RuleMark(y: .value("Zero", 0)).foregroundStyle(Theme.Colors.accent)
                }
                if let selectedDate {
                    let now = currentPoints.last { calendar.startOfDay(for: $0.date) <= calendar.startOfDay(for: selectedDate) }?.value ?? 0
                    let before = shiftedPrevious.last { calendar.startOfDay(for: $0.date) <= calendar.startOfDay(for: selectedDate) }?.value ?? 0
                    RuleMark(x: .value("Selected", selectedDate, unit: .day))
                        .foregroundStyle(Theme.Colors.chartMuted)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            ChartCallout(
                                title: DateFormatting.monthDay.string(from: selectedDate),
                                value: "\(Money(double: now).compact()) vs \(Money(double: before).compact())",
                                color: Theme.Colors.accent
                            )
                        }
                }
            }
            .chartXScale(domain: thisMonth.start...thisMonth.end)
            .chartXSelection(value: $selectedDate)
            .reportAxes(month: thisMonth, calendar: calendar)
            .frame(height: 160)
        }
    }
}

// MARK: - Last 7 months

struct MonthlySpendCard: View {
    var store: BudgetStore
    @State private var selectedMonth: Date?

    var body: some View {
        let totals = store.calculator.monthlyTotals(transactions: store.transactions, months: 7, currency: store.settings.currencyCode)
        let calendar = store.calendar
        let selected = selectedMonth.flatMap { month in totals.first { calendar.isDate($0.month, equalTo: month, toGranularity: .month) } }

        ReportCard(title: "Monthly spend (last 7 months)") {
            EmptyView()
        } content: {
            if totals.isEmpty {
                EmptyState(title: "No history yet", message: "Monthly totals appear once you've logged some spending.")
                    .frame(height: 160)
            } else {
                Chart {
                    ForEach(totals) { total in
                        BarMark(
                            x: .value("Month", total.month, unit: .month),
                            y: .value("Spent", total.spent.doubleValue),
                            width: .ratio(0.55)
                        )
                        .cornerRadius(4, style: .continuous)
                        .foregroundStyle(Theme.Colors.accent.opacity(selected == nil || selected?.month == total.month ? 1 : 0.35))
                        .annotation(position: .top, spacing: 4) {
                            if selected?.month == total.month {
                                ChartCallout(title: DateFormatting.monthYear.string(from: total.month), value: total.spent.display, color: Theme.Colors.accent)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedMonth)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Theme.Colors.gridLine)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) { Text(Money(double: amount).compact()) }
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .frame(height: 180)
            }
        }
    }
}

// MARK: - Spending by category

struct CategoryBreakdownCard: View {
    var store: BudgetStore

    var body: some View {
        let month = store.calculator.interval(for: .monthly, containing: Date())
        let items = store.calculator.spendingByCategory(
            transactions: store.transactions,
            categories: store.categories,
            in: month,
            currency: store.settings.currencyCode
        ).filter { $0.spent.amount > 0 }
        let maxSpent = items.map(\.spent.doubleValue).max() ?? 1

        ReportCard(title: "Spending by category") {
            Text(DateFormatting.monthYear.string(from: month.start))
                .font(.system(size: 11))
                .foregroundStyle(Theme.Colors.textSecondary)
        } content: {
            if items.isEmpty {
                EmptyState(title: "No spending this month", message: "Categories you spend in will be ranked here.")
            } else {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            CategoryCircle(category: item.category, size: 28)
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(item.category.name)
                                        .font(Theme.Fonts.rowTitle)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.spent.display)
                                        .font(Theme.Fonts.rowTitle)
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                }
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(Color(hex: item.category.colorHex))
                                        .frame(width: max(proxy.size.width * item.spent.doubleValue / max(maxSpent, 0.01), 6))
                                }
                                .frame(height: 6)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .animation(Theme.springAnimation, value: items.map(\.spent))
            }
        }
    }
}

#if os(iOS)
#Preview {
    ReportsView(store: .preview())
}
#endif
