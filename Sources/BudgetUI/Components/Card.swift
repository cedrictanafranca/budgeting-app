import SwiftUI

/// White, softly bordered container used by Home, Reports and Accounts (Luna's cards).
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    var elevated: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cardRadius, style: .continuous)
                    .fill(Theme.Colors.cardElevated)
                    .shadow(color: elevated ? Theme.Colors.shadow : .clear, radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cardRadius, style: .continuous)
                    .strokeBorder(Theme.Colors.separator, lineWidth: 1)
            )
    }
}

/// Small grey label above a group of rows ("Account Settings", "Bank Accounts").
struct SectionLabel: View {
    var title: String
    var prominent: Bool = false

    init(_ title: String, prominent: Bool = false) {
        self.title = title
        self.prominent = prominent
    }

    var body: some View {
        Text(title)
            .font(prominent ? Theme.Fonts.cardTitle : Theme.Fonts.sectionLabel)
            .foregroundStyle(prominent ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, prominent ? 8 : 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Dashed outline button: "Add new category", "Add Account".
struct DashedAddRow: View {
    var title: String
    var showsIcon: Bool = true
    var height: CGFloat = 52
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if showsIcon {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(Theme.Fonts.rowTitle)
            }
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cardRadius, style: .continuous)
                    .strokeBorder(Theme.Colors.textTertiary, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Text-only empty state (no illustrations).
struct EmptyState: View {
    var title: String
    var message: String
    var systemImage: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.bottom, 4)
            }
            Text(title)
                .font(Theme.Fonts.cardTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(message)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
}

/// Grey rounded row used in Settings and editor forms (label left, control right).
struct FieldRow<Trailing: View>: View {
    var title: String
    var systemImage: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 22)
            }
            Text(title)
                .font(Theme.Fonts.rowTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 12)
            trailing
                .font(Theme.Fonts.rowTitle)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: Theme.Layout.rowHeight - 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Colors.card)
        )
    }
}

/// Full-width capsule call to action ("Continue", "Save").
struct PrimaryButton: View {
    var title: String
    var color: Color = Theme.Colors.continueButton
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(color))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .animation(.easeOut(duration: 0.15), value: isEnabled)
    }
}

/// Subtle scale-down on press used by FAB, keypad and primary buttons.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    /// Screen background + horizontal padding shared by the tab screens.
    func screenBackground() -> some View {
        background(Theme.Colors.background.ignoresSafeArea())
    }

    /// Large inline title on iOS; plain title elsewhere.
    func largeNavigationTitle(_ title: String) -> some View {
        #if os(iOS)
        return navigationTitle(title).navigationBarTitleDisplayMode(.large)
        #else
        return navigationTitle(title)
        #endif
    }

    func inlineNavigationTitle(_ title: String) -> some View {
        #if os(iOS)
        return navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        #else
        return navigationTitle(title)
        #endif
    }

    /// Decimal keyboard on iOS; no-op on macOS.
    func decimalKeyboard() -> some View {
        #if os(iOS)
        return keyboardType(.decimalPad)
        #else
        return self
        #endif
    }

    func wordsCapitalization() -> some View {
        #if os(iOS)
        return textInputAutocapitalization(.words)
        #else
        return self
        #endif
    }

    /// Hides the navigation bar on iOS (Home has no title in the Luna reference).
    func hiddenNavigationBar() -> some View {
        #if os(iOS)
        return toolbar(.hidden, for: .navigationBar)
        #else
        return self
        #endif
    }
}
