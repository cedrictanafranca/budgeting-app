import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home, reports, accounts, transactions, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .reports: return "Reports"
        case .accounts: return "Accounts"
        case .transactions: return "Transactions"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .reports: return "chart.bar.fill"
        case .accounts: return "wallet.bifold.fill"
        case .transactions: return "creditcard.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var showsAddButton: Bool { self != .settings }
}

/// Luna's floating white capsule tab bar. The active tab sits on a soft rounded pill.
struct FloatingTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    guard selection != tab else { return }
                    Haptics.selection()
                    withAnimation(Theme.springAnimation) { selection = tab }
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selection == tab ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            if selection == tab {
                                Capsule(style: .continuous)
                                    .fill(Theme.Colors.tabActive)
                                    .matchedGeometryEffect(id: "activeTab", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.Colors.tabBar)
                .shadow(color: Theme.Colors.shadow, radius: 16, x: 0, y: 6)
        )
        .overlay(Capsule(style: .continuous).strokeBorder(Theme.Colors.separator.opacity(0.6), lineWidth: 0.5))
    }
}

/// Black circular "+" floating action button.
struct FAB: View {
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.impact()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.Colors.fabForeground)
                .frame(width: Theme.Layout.fabSize, height: Theme.Layout.fabSize)
                .background(Circle().fill(Theme.Colors.fab))
                .shadow(color: Theme.Colors.shadow, radius: 10, x: 0, y: 4)
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.92))
        .accessibilityLabel("Add transaction")
    }
}

#if os(iOS)
#Preview {
    struct Demo: View {
        @State var tab: AppTab = .home
        var body: some View {
            VStack(alignment: .trailing, spacing: 14) {
                FAB {}
                FloatingTabBar(selection: $tab)
            }
            .padding()
        }
    }
    return Demo()
}
#endif
