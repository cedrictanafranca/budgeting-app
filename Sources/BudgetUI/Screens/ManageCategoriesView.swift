import SwiftUI
import BudgetCore

/// Settings → Categories: reorder within a period, archive / unarchive, edit, add.
struct ManageCategoriesView: View {
    @Bindable var store: BudgetStore
    @State private var editing: BudgetCore.Category?
    @State private var addingPeriod: BudgetPeriod?

    private var archived: [BudgetCore.Category] { store.categories.filter(\.isArchived) }

    var body: some View {
        List {
            ForEach(BudgetPeriod.allCases) { period in
                let items = store.activeCategories.filter { $0.period == period }
                Section {
                    ForEach(items) { category in
                        row(category)
                            .swipeActions(edge: .trailing) {
                                Button { setArchived(category, true) } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(Theme.Colors.textSecondary)
                            }
                    }
                    .onMove { source, destination in move(in: period, from: source, to: destination) }
                    Button {
                        addingPeriod = period
                    } label: {
                        Label("Add \(period.title.lowercased()) category", systemImage: "plus.circle.fill")
                            .font(Theme.Fonts.rowTitle)
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(period.title)
                }
            }
            if !archived.isEmpty {
                Section {
                    ForEach(archived) { category in
                        row(category)
                            .opacity(0.6)
                            .swipeActions(edge: .trailing) {
                                Button { setArchived(category, false) } label: {
                                    Label("Unarchive", systemImage: "tray.and.arrow.up")
                                }
                                .tint(Theme.Colors.accent)
                            }
                    }
                } header: {
                    Text("Archived")
                }
            }
        }
        .inlineNavigationTitle("Categories")
        #if os(iOS)
        .toolbar { EditButton() }
        #endif
        .sheet(item: $editing) { category in
            CategoryEditor(store: store, category: category)
        }
        .sheet(item: $addingPeriod) { period in
            CategoryEditor(store: store, category: nil, defaultPeriod: period)
        }
    }

    private func row(_ category: BudgetCore.Category) -> some View {
        Button { editing = category } label: {
            HStack(spacing: 12) {
                CategoryCircle(category: category)
                Text(category.name)
                    .font(Theme.Fonts.rowTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text(category.budget?.display ?? "No budget")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { setArchived(category, !category.isArchived) } label: {
                Label(category.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
            }
        }
    }

    private func setArchived(_ category: BudgetCore.Category, _ archived: Bool) {
        var updated = category
        updated.isArchived = archived
        try? store.save(updated)
    }

    /// Reorders inside one period, then rewrites sortOrder across all categories so it stays global.
    private func move(in period: BudgetPeriod, from source: IndexSet, to destination: Int) {
        var items = store.activeCategories.filter { $0.period == period }
        items.move(fromOffsets: source, toOffset: destination)
        var ordered: [BudgetCore.Category] = []
        for group in BudgetPeriod.allCases {
            ordered += group == period ? items : store.activeCategories.filter { $0.period == group }
        }
        ordered += store.categories.filter(\.isArchived)
        for (index, var category) in ordered.enumerated() where category.sortOrder != index {
            category.sortOrder = index
            try? store.save(category)
        }
    }
}

#if os(iOS)
#Preview {
    NavigationStack { ManageCategoriesView(store: .preview()) }
}
#endif
