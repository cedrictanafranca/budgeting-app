import AppIntents
import BudgetCore
import Foundation

/// A budget category, pickable as a parameter in the Shortcuts editor.
public struct CategoryEntity: AppEntity, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let emoji: String

    public init(id: UUID, name: String, emoji: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
    }

    public init(_ category: BudgetCore.Category) {
        self.init(id: category.id, name: category.name, emoji: category.emoji)
    }

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    public static let defaultQuery = CategoryQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }
}

/// Looks categories up in the shared `BudgetStore` (registered via `BudgetIntentsBootstrap`).
public struct CategoryQuery: EntityStringQuery {
    @Dependency private var store: BudgetStore

    public init() {}

    @MainActor
    public func entities(for identifiers: [CategoryEntity.ID]) async throws -> [CategoryEntity] {
        identifiers.compactMap { id in store.category(id: id).map(CategoryEntity.init) }
    }

    @MainActor
    public func suggestedEntities() async throws -> [CategoryEntity] {
        store.activeCategories.map(CategoryEntity.init)
    }

    @MainActor
    public func entities(matching string: String) async throws -> [CategoryEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.activeCategories.map(CategoryEntity.init) }
        return store.activeCategories
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .map(CategoryEntity.init)
    }
}
