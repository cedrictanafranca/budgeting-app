import SwiftUI
import UniformTypeIdentifiers
import BudgetCore
#if os(macOS)
import AppKit
#endif

/// IMG_1876: avatar, Account Settings, App Settings, Categories, Data. (No Subscription section.)
struct SettingsView: View {
    @Bindable var store: BudgetStore
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    @State private var name = ""
    @State private var incomeTargetText = ""
    @FocusState private var focusedField: Field?
    @State private var importing = false
    @State private var pendingRestore: BudgetSnapshot?
    @State private var statusMessage: String?

    private enum Field { case name, incomeTarget }

    static let currencies = ["CAD", "USD", "EUR", "GBP"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    avatar
                    accountSettings
                    appSettings
                    categories
                    data
                    if let statusMessage {
                        Text(statusMessage)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, Theme.Layout.screenPadding)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .largeNavigationTitle("Settings")
            .navigationDestination(for: String.self) { route in
                if route == "categories" { ManageCategoriesView(store: store) }
            }
            .onAppear(perform: loadFields)
            .onChange(of: focusedField) { old, _ in
                if old == .name { saveName() }
                if old == .incomeTarget { saveIncomeTarget() }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .commaSeparatedText, .plainText]) { result in
                handleImport(result)
            }
            .confirmationDialog("Replace all data?", isPresented: restoreBinding, titleVisibility: .visible) {
                Button("Replace everything", role: .destructive) { applyRestore() }
            } message: {
                Text("Your current transactions, categories and accounts will be replaced by the file's contents.")
            }
        }
    }

    // MARK: Sections

    private var avatar: some View {
        let initial = store.settings.userName.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
        return Circle()
            .fill(Theme.Colors.avatar)
            .frame(width: 56, height: 56)
            .overlay(Text(initial).font(.system(size: 24, weight: .regular)).foregroundStyle(.white))
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
            .accessibilityHidden(true)
    }

    private var accountSettings: some View {
        Group {
            SectionLabel("Account Settings")
            FieldRow(title: "Name") {
                TextField("Your name", text: $name)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .name)
                    .wordsCapitalization()
                    .onSubmit(saveName)
            }
            FieldRow(title: "Currency") {
                Menu {
                    Picker("Currency", selection: settingBinding(\.currencyCode)) {
                        ForEach(Self.currencies, id: \.self) { Text($0).tag($0) }
                    }
                } label: { menuLabel(store.settings.currencyCode) }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            FieldRow(title: "Week starts on") {
                Menu {
                    Picker("Week starts on", selection: settingBinding(\.weekStartsOn)) {
                        ForEach(1...7, id: \.self) { day in
                            Text(store.calendar.weekdaySymbols[day - 1]).tag(day)
                        }
                    }
                } label: { menuLabel(store.calendar.weekdaySymbols[max(0, min(6, store.settings.weekStartsOn - 1))]) }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            FieldRow(title: "Monthly income target") {
                TextField("None", text: $incomeTargetText)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .decimalKeyboard()
                    .focused($focusedField, equals: .incomeTarget)
                    .onSubmit(saveIncomeTarget)
            }
        }
    }

    private var appSettings: some View {
        Group {
            SectionLabel("App Settings").padding(.top, 8)
            FieldRow(title: "Appearance") {
                Menu {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                    }
                } label: { menuLabel(appearance.title) }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    private var categories: some View {
        Group {
            SectionLabel("Categories").padding(.top, 8)
            NavigationLink(value: "categories") {
                FieldRow(title: "Manage categories") {
                    HStack(spacing: 6) {
                        Text("\(store.activeCategories.count)")
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var data: some View {
        Group {
            SectionLabel("Data").padding(.top, 8)
            #if os(iOS)
            ShareLink(item: CSVExport(snapshot: store.snapshot), preview: SharePreview("Transactions.csv")) {
                FieldRow(title: "Export CSV", systemImage: "tablecells") { Image(systemName: "square.and.arrow.up") }
            }
            .buttonStyle(.plain)
            ShareLink(item: BackupExport(snapshot: store.snapshot), preview: SharePreview("Budget Backup.json")) {
                FieldRow(title: "Backup (JSON)", systemImage: "externaldrive") { Image(systemName: "square.and.arrow.up") }
            }
            .buttonStyle(.plain)
            #else
            Button { copyCSV() } label: {
                FieldRow(title: "Copy CSV export", systemImage: "tablecells") { Image(systemName: "doc.on.doc") }
            }
            .buttonStyle(.plain)
            Button { copyBackup() } label: {
                FieldRow(title: "Copy backup (JSON)", systemImage: "externaldrive") { Image(systemName: "doc.on.doc") }
            }
            .buttonStyle(.plain)
            #endif
            Button { importing = true } label: {
                FieldRow(title: "Restore from file", systemImage: "arrow.down.doc") { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.plain)
            Text("Restore accepts a JSON backup (replaces everything) or a CSV export (adds new rows).")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.horizontal, 4)
        }
    }

    private func menuLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Theme.Colors.textSecondary)
    }

    // MARK: Settings persistence

    private func settingBinding<Value>(_ keyPath: WritableKeyPath<BudgetSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { newValue in
                var settings = store.settings
                settings[keyPath: keyPath] = newValue
                try? store.save(settings)
            }
        )
    }

    private func loadFields() {
        name = store.settings.userName
        incomeTargetText = store.settings.monthlyIncomeTarget.map { NSDecimalNumber(decimal: $0.amount).stringValue } ?? ""
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed != store.settings.userName else { return }
        var settings = store.settings
        settings.userName = trimmed
        try? store.save(settings)
    }

    private func saveIncomeTarget() {
        var settings = store.settings
        let trimmed = incomeTargetText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            settings.monthlyIncomeTarget = nil
        } else if let money = Money(string: trimmed, currency: settings.currencyCode), money.amount > 0 {
            settings.monthlyIncomeTarget = money.rounded
        } else {
            loadFields()
            return
        }
        guard settings != store.settings else { return }
        try? store.save(settings)
    }

    // MARK: Import / export

    private var restoreBinding: Binding<Bool> {
        Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            show("Couldn't open file: \(error.localizedDescription)")
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                if url.pathExtension.lowercased() == "json" {
                    pendingRestore = try BackupCodec().decode(data)
                } else {
                    let text = String(decoding: data, as: UTF8.self)
                    let merged = try CSVCodec().import(text, into: store.snapshot)
                    let added = merged.transactions.count - store.transactions.count
                    try store.restore(from: merged)
                    show("Imported \(max(added, 0)) transactions.")
                }
            } catch {
                show("Couldn't read file: \(error.localizedDescription)")
            }
        }
    }

    private func applyRestore() {
        guard let snapshot = pendingRestore else { return }
        pendingRestore = nil
        do {
            try store.restore(from: snapshot)
            loadFields()
            Haptics.success()
            show("Restored \(snapshot.transactions.count) transactions.")
        } catch {
            show("Restore failed: \(error.localizedDescription)")
        }
    }

    #if os(macOS)
    private func copyCSV() {
        copyToPasteboard(CSVCodec().export(store.snapshot))
        show("CSV copied to the clipboard.")
    }

    private func copyBackup() {
        guard let data = try? BackupCodec().encode(store.snapshot) else { show("Backup failed."); return }
        copyToPasteboard(String(decoding: data, as: UTF8.self))
        show("Backup copied to the clipboard.")
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    #endif

    private func show(_ message: String) {
        withAnimation { statusMessage = message }
    }
}

/// Lazily encoded CSV for ShareLink.
struct CSVExport: Transferable {
    var snapshot: BudgetSnapshot
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            Data(CSVCodec().export(export.snapshot).utf8)
        }
        .suggestedFileName("Transactions.csv")
    }
}

/// Lazily encoded JSON backup for ShareLink.
struct BackupExport: Transferable {
    var snapshot: BudgetSnapshot
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { export in
            try BackupCodec().encode(export.snapshot)
        }
        .suggestedFileName("Budget Backup.json")
    }
}

#if os(iOS)
#Preview {
    SettingsView(store: .preview())
}
#endif
