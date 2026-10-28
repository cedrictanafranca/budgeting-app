import SwiftUI
import BudgetCore

/// Root view the app target presents. Owns the floating tab bar, the "+" button and the
/// add-transaction flow, and surfaces persistence errors from the store.
public struct RootView: View {
    @Bindable var store: BudgetStore
    @State private var tab: AppTab = .home
    @State private var showingAdd = false
    @State private var acknowledgedError: BudgetError?
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    public init(store: BudgetStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            content
                .id(tab)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.18), value: tab)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .preferredColorScheme(appearance.colorScheme)
        .tint(Theme.Colors.accent)
        .alert("Something went wrong", isPresented: errorBinding, presenting: store.lastError) { _ in
            Button("OK", role: .cancel) { acknowledgedError = store.lastError }
        } message: { error in
            Text(error.errorDescription ?? "Please try again.")
        }
        .addTransactionPresentation(isPresented: $showingAdd) {
            AddTransactionFlow(store: store) { showingAdd = false }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home: HomeView(store: store)
        case .reports: ReportsView(store: store)
        case .accounts: AccountsView(store: store)
        case .transactions: TransactionsView(store: store)
        case .settings: SettingsView(store: store)
        }
    }

    private var bottomBar: some View {
        VStack(alignment: .trailing, spacing: 14) {
            if tab.showsAddButton {
                FAB { showingAdd = true }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            FloatingTabBar(selection: $tab)
        }
        .animation(Theme.springAnimation, value: tab.showsAddButton)
        .padding(.horizontal, Theme.Layout.screenPadding)
        .padding(.bottom, 16)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.lastError != nil && store.lastError != acknowledgedError && !showingAdd },
            set: { presented in if !presented { acknowledgedError = store.lastError } }
        )
    }
}

/// Appearance override stored in AppStorage and applied at the root.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    static let storageKey = "appearanceMode"
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension View {
    /// Full-screen cover on iOS (Luna's add flow covers the screen); a sheet elsewhere.
    @ViewBuilder
    func addTransactionPresentation<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented) {
            content().frame(minWidth: 420, minHeight: 640)
        }
        #endif
    }
}

#if os(iOS)
#Preview("Root") {
    RootView(store: .preview())
}

#Preview("Root – empty") {
    RootView(store: .preview(sample: false))
}
#endif
