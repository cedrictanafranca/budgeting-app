import SwiftUI
import BudgetCore

struct AccountRoute: Hashable {
    var id: UUID
}

/// IMG_1872: accounts grouped into "Bank Accounts" and "Credit Cards".
struct AccountsView: View {
    @Bindable var store: BudgetStore
    @State private var showingNewAccount = false

    private var groups: [(title: String, accounts: [Account])] {
        let grouped = Dictionary(grouping: store.activeAccounts) { $0.type.groupTitle }
        return ["Bank Accounts", "Credit Cards"].compactMap { title in
            guard let accounts = grouped[title], !accounts.isEmpty else { return nil }
            return (title, accounts)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groups, id: \.title) { group in
                        SectionLabel(group.title, prominent: true)
                        ForEach(group.accounts) { account in
                            NavigationLink(value: AccountRoute(id: account.id)) {
                                AccountCard(account: account, store: store)
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.98))
                        }
                    }
                    DashedAddRow(title: "Add Account", height: 72) { showingNewAccount = true }
                        .padding(.top, 12)
                }
                .padding(.horizontal, Theme.Layout.screenPadding)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .largeNavigationTitle("Accounts")
            .navigationDestination(for: AccountRoute.self) { route in
                AccountDetailView(store: store, accountID: route.id)
            }
            .sheet(isPresented: $showingNewAccount) {
                AccountEditor(store: store, account: nil)
            }
        }
    }
}

/// White elevated account card with icon tile, "Updated N days ago", balance and a sparkline.
struct AccountCard: View {
    var account: Account
    var store: BudgetStore

    var body: some View {
        let balance = store.calculator.balance(for: account, transactions: store.transactions)
        let lastActivity = store.calculator.lastActivity(for: account, transactions: store.transactions)
        Card(elevated: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    AccountIconTile(account: account)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(account.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Text(DateFormatting.updatedLabel(lastActivity ?? account.openingDate, calendar: store.calendar))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    if account.isDefaultForExpenses {
                        Text("Default")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Colors.accent)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(Theme.Colors.accentSoft.opacity(0.9)))
                    }
                }
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Balance")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text(balance.display)
                            .font(Theme.Fonts.balance)
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    Sparkline(values: AccountMath.trend(for: account, transactions: store.transactions, calendar: store.calendar))
                        .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .frame(width: 64, height: 22)
                        .padding(.bottom, 4)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

/// Minimal line shape; a flat series draws a flat line (as in the Luna screenshot).
struct Sparkline: Shape {
    var values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            return path
        }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let span = maxValue - minValue
        for (index, value) in values.enumerated() {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1)
            let normalized = span == 0 ? 0 : (value - minValue) / span
            let y = rect.maxY - rect.height * CGFloat(normalized)
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

enum AccountMath {
    /// How a transaction moves this account's displayed balance (owed amount for credit cards).
    static func effect(of transaction: BudgetTransaction, on account: Account) -> Decimal {
        let amount = transaction.amount.amount
        let liability = account.type.isLiability
        var delta: Decimal = 0
        if transaction.accountID == account.id {
            switch transaction.kind {
            case .expense: delta += liability ? amount : -amount
            case .income: delta += liability ? -amount : amount
            case .transfer: delta += liability ? amount : -amount
            }
        }
        if transaction.kind == .transfer && transaction.transferToAccountID == account.id {
            delta += liability ? -amount : amount
        }
        return delta
    }

    /// Running relative balance across the last 30 days, one point per day.
    static func trend(for account: Account, transactions: [BudgetTransaction], calendar: Calendar, days: Int = 30) -> [Double] {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }
        var perDay = [Decimal](repeating: 0, count: days)
        for transaction in transactions where transaction.date >= start {
            let delta = effect(of: transaction, on: account)
            guard delta != 0 else { continue }
            let index = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: transaction.date)).day ?? 0
            if (0..<days).contains(index) { perDay[index] += delta }
        }
        var running: Decimal = 0
        return perDay.map { running += $0; return NSDecimalNumber(decimal: running).doubleValue }
    }
}

#if os(iOS)
#Preview {
    AccountsView(store: .preview())
}
#endif
