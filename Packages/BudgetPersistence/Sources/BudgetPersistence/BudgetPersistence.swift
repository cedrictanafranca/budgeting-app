import Foundation

public enum BudgetPersistence {
    /// Shared container for the app, widgets and (future) extensions. Must match
    /// App/Budgeting/Budgeting.entitlements and the App Group enabled in Xcode.
    public static let appGroupID = "group.com.cedrictanafranca.budgeting"

    /// Key of the single `SettingsRecord` row.
    public static let settingsKey = "settings"

    /// File name of the SwiftData store inside the App Group container.
    public static let storeFileName = "Budget.store"

    /// `<App Group>/Library/Application Support/Budget.store`, or nil when the App Group
    /// entitlement is missing (e.g. signing without the capability).
    public static func appGroupStoreURL(fileManager: FileManager = .default) -> URL? {
        guard let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return nil }
        let directory = groupURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return directory.appendingPathComponent(storeFileName, isDirectory: false)
    }
}
