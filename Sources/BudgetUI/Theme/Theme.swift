import SwiftUI

/// Design tokens derived from the Luna reference screenshots (docs/references/luna).
/// Keep all colors/radii/spacing here so screens stay consistent.
public enum Theme {
    // MARK: Colors
    public enum Colors {
        /// Primary accent — Luna's vivid indigo used for charts, links and the active tab.
        public static let accent = Color(hex: "#5B3DF5")
        public static let accentSoft = Color(hex: "#EEEBFE")
        /// Positive money (remaining budget, income).
        public static let positive = Color(hex: "#16A34A")
        public static let positiveSoft = Color(hex: "#DCFCE7")
        /// Negative money (over budget).
        public static let negative = Color(hex: "#DC2626")
        public static let negativeSoft = Color(hex: "#FEE2E2")
        /// The neutral "$0.00" pill.
        public static let neutralPill = Color(hex: "#F3F4F6")
        public static let warningBanner = Color(hex: "#FDE047")

        public static let background = Color(light: "#FFFFFF", dark: "#000000")
        public static let card = Color(light: "#F6F6F8", dark: "#1C1C1E")
        public static let cardElevated = Color(light: "#FFFFFF", dark: "#1C1C1E")
        public static let separator = Color(light: "#ECECF0", dark: "#2C2C2E")
        public static let textPrimary = Color(light: "#111111", dark: "#FFFFFF")
        public static let textSecondary = Color(light: "#8E8E93", dark: "#8E8E93")
        public static let textTertiary = Color(light: "#C7C7CC", dark: "#48484A")
        public static let fab = Color(light: "#111111", dark: "#FFFFFF")
        public static let fabForeground = Color(light: "#FFFFFF", dark: "#111111")
        public static let continueButton = Color(hex: "#34C759")
    }

    // MARK: Typography (SF Pro via system fonts; rounded avoided to match Luna)
    public enum Fonts {
        public static let screenTitle = Font.system(size: 28, weight: .bold)
        public static let cardTitle = Font.system(size: 17, weight: .semibold)
        public static let body = Font.system(size: 16, weight: .medium)
        public static let rowTitle = Font.system(size: 15, weight: .medium)
        public static let caption = Font.system(size: 12, weight: .regular)
        public static let sectionLabel = Font.system(size: 12, weight: .medium)
        public static let pill = Font.system(size: 13, weight: .semibold)
        public static let keypad = Font.system(size: 28, weight: .regular)
        public static let amountDisplay = Font.system(size: 56, weight: .semibold)
        public static let balance = Font.system(size: 20, weight: .bold)
    }

    // MARK: Layout
    public enum Layout {
        public static let screenPadding: CGFloat = 20
        public static let cardRadius: CGFloat = 16
        public static let pillRadius: CGFloat = 8
        public static let rowHeight: CGFloat = 52
        public static let categoryCircle: CGFloat = 30
        public static let fabSize: CGFloat = 56
        public static let tabBarHeight: CGFloat = 64
        public static let cardSpacing: CGFloat = 16
    }

    public static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.8)
}

public extension Color {
    /// "#RRGGBB" or "#RRGGBBAA".
    init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        switch cleaned.count {
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Adaptive color from two hex strings.
    init(light: String, dark: String) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(Color(hex: dark)) : NSColor(Color(hex: light))
        })
        #else
        self.init(hex: light)
        #endif
    }
}
