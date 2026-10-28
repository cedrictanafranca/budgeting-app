import SwiftUI
import BudgetCore

enum RangeKind: String, CaseIterable, Identifiable {
    case week, month
    var id: String { rawValue }
    var title: String { self == .week ? "Week" : "Month" }
    var period: BudgetPeriod { self == .week ? .weekly : .monthly }
}

/// "< Oct 25 - Oct 31, 2026 >" with a trailing "Week ▾" menu.
struct RangeNavigator: View {
    var interval: DateInterval
    @Binding var kind: RangeKind
    var canGoForward: Bool = true
    var onPrevious: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 24, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Colors.accent)
            .accessibilityLabel("Previous \(kind.title.lowercased())")

            Text(DateFormatting.rangeLabel(interval))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 24, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Colors.accent)
            .opacity(canGoForward ? 1 : 0.3)
            .disabled(!canGoForward)
            .accessibilityLabel("Next \(kind.title.lowercased())")

            Spacer(minLength: 8)

            Menu {
                Picker("Range", selection: $kind) {
                    ForEach(RangeKind.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(kind.title)
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Colors.accent)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

/// Date strings used across screens.
enum DateFormatting {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate(format)
        return formatter
    }

    static let monthDay = formatter("MMMd")
    static let monthDayYear = formatter("MMMdyyyy")
    static let monthYear = formatter("MMMMyyyy")

    /// "Oct 25 - Oct 31, 2026" (end is exclusive in DateInterval, so step back one second).
    static func rangeLabel(_ interval: DateInterval) -> String {
        let end = interval.end.addingTimeInterval(-1)
        let calendar = Calendar.current
        if calendar.component(.year, from: interval.start) == calendar.component(.year, from: end) {
            return "\(monthDay.string(from: interval.start)) - \(monthDayYear.string(from: end))"
        }
        return "\(monthDayYear.string(from: interval.start)) - \(monthDayYear.string(from: end))"
    }

    /// "Updated today", "Updated yesterday", "Updated 147 days ago".
    static func updatedLabel(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date else { return "No activity yet" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "Updated today"
        case 1: return "Updated yesterday"
        default: return "Updated \(days) days ago"
        }
    }

    static func daysLeftLabel(_ days: Int) -> String {
        days == 1 ? "1 day left" : "\(days) days left"
    }
}
