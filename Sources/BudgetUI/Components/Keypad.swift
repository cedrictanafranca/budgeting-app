import SwiftUI

enum KeypadKey: Hashable {
    case digit(Int), decimal, delete
}

/// 4×3 number pad (1–9, ".", 0, delete) from the Luna amount entry screen.
struct Keypad: View {
    var onKey: (KeypadKey) -> Void

    private let rows: [[KeypadKey]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.decimal, .digit(0), .delete],
    ]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(rows[row], id: \.self) { key in
                        Button {
                            Haptics.impact()
                            onKey(key)
                        } label: {
                            label(for: key)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(KeypadButtonStyle())
                        .accessibilityLabel(accessibilityLabel(for: key))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func label(for key: KeypadKey) -> some View {
        switch key {
        case .digit(let value):
            Text("\(value)").font(Theme.Fonts.keypad)
        case .decimal:
            Text(".").font(Theme.Fonts.keypad)
        case .delete:
            Image(systemName: "delete.left").font(.system(size: 22, weight: .regular))
        }
    }

    private func accessibilityLabel(for key: KeypadKey) -> String {
        switch key {
        case .digit(let value): return "\(value)"
        case .decimal: return "Decimal point"
        case .delete: return "Delete"
        }
    }
}

private struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.Colors.textPrimary)
            .background(
                Circle()
                    .fill(Theme.Colors.pillNeutral)
                    .frame(width: 64, height: 64)
                    .opacity(configuration.isPressed ? 1 : 0)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Pure keypad input rules, kept separate so they're easy to reason about.
enum AmountInput {
    static let maxIntegerDigits = 9

    /// Applies a key to the current entry string ("" means zero). Max 2 decimals, one ".".
    static func apply(_ key: KeypadKey, to text: String) -> String {
        switch key {
        case .delete:
            return String(text.dropLast())
        case .decimal:
            if text.contains(".") { return text }
            return text.isEmpty ? "0." : text + "."
        case .digit(let value):
            if let dot = text.firstIndex(of: ".") {
                if text[text.index(after: dot)...].count >= 2 { return text }
                return text + "\(value)"
            }
            if text == "0" { return value == 0 ? text : "\(value)" }
            if text.count >= maxIntegerDigits { return text }
            if text.isEmpty && value == 0 { return "0" }
            return text + "\(value)"
        }
    }

    static func decimal(from text: String) -> Decimal {
        guard !text.isEmpty else { return 0 }
        let normalized = text.hasSuffix(".") ? String(text.dropLast()) : text
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    /// Display with grouping, preserving what the user typed after the decimal point.
    static func display(_ text: String) -> String {
        guard !text.isEmpty else { return "0" }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let integer = String(parts[0].isEmpty ? "0" : parts[0])
        var grouped = ""
        for (index, char) in integer.reversed().enumerated() {
            if index > 0 && index % 3 == 0 { grouped.append(",") }
            grouped.append(char)
        }
        grouped = String(grouped.reversed())
        if parts.count > 1 { return grouped + "." + parts[1] }
        return grouped
    }
}

#if os(iOS)
#Preview {
    Keypad { _ in }
        .padding()
}
#endif
