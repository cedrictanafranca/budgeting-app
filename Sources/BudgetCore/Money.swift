import Foundation

/// Decimal-safe monetary value. Never use Double for amounts.
public struct Money: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public var amount: Decimal
    public var currencyCode: String

    public init(_ amount: Decimal, currency: String = Money.defaultCurrency) {
        self.amount = amount
        self.currencyCode = currency
    }

    /// Construct from a user-typed string such as "12.50" or "1,234.00". Returns nil if unparseable.
    public init?(string: String, currency: String = Money.defaultCurrency) {
        let cleaned = string
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "CA", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        self.init(value, currency: currency)
    }

    /// Construct from a Double coming from an untrusted source (e.g. Shortcuts). Rounds to 2 decimals.
    public init(double: Double, currency: String = Money.defaultCurrency) {
        let decimal = Decimal(string: String(format: "%.2f", double), locale: Locale(identifier: "en_US_POSIX")) ?? 0
        self.init(decimal, currency: currency)
    }

    public static let defaultCurrency = "CAD"
    public static func zero(_ currency: String = Money.defaultCurrency) -> Money { Money(0, currency: currency) }

    public var isZero: Bool { amount == 0 }
    public var isNegative: Bool { amount < 0 }

    /// Rounded to 2 decimal places using banker's rounding.
    public var rounded: Money {
        var value = amount
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .bankers)
        return Money(result, currency: currencyCode)
    }

    public var doubleValue: Double { NSDecimalNumber(decimal: amount).doubleValue }

    // MARK: Arithmetic (same-currency only; currency of lhs wins)
    public static func + (lhs: Money, rhs: Money) -> Money { Money(lhs.amount + rhs.amount, currency: lhs.currencyCode) }
    public static func - (lhs: Money, rhs: Money) -> Money { Money(lhs.amount - rhs.amount, currency: lhs.currencyCode) }
    public static prefix func - (value: Money) -> Money { Money(-value.amount, currency: value.currencyCode) }
    public static func * (lhs: Money, rhs: Decimal) -> Money { Money(lhs.amount * rhs, currency: lhs.currencyCode) }
    public static func += (lhs: inout Money, rhs: Money) { lhs = lhs + rhs }
    public static func -= (lhs: inout Money, rhs: Money) { lhs = lhs - rhs }
    public static func < (lhs: Money, rhs: Money) -> Bool { lhs.amount < rhs.amount }

    public static func sum(_ values: [Money], currency: String = Money.defaultCurrency) -> Money {
        values.reduce(Money.zero(currency), +)
    }

    // MARK: Formatting

    /// "CA$12.50" style, matching the Luna reference. Pass `showsCode: false` for "$12.50".
    public func formatted(showsCode: Bool = true, signed: Bool = false, fractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        let magnitude = NSDecimalNumber(decimal: abs(amount))
        let number = formatter.string(from: magnitude) ?? "0.00"
        let prefix = showsCode ? Money.symbolPrefix(for: currencyCode) : "$"
        let sign: String
        if amount < 0 { sign = "-" } else if signed && amount > 0 { sign = "+" } else { sign = "" }
        return "\(sign)\(prefix)\(number)"
    }

    /// Compact form for tight spaces: "$1.2K", "$750".
    public func compact() -> String {
        let value = abs(doubleValue)
        let sign = amount < 0 ? "-" : ""
        if value >= 1_000_000 { return "\(sign)$\(String(format: "%.1f", value / 1_000_000))M" }
        if value >= 1_000 {
            let k = value / 1_000
            return k == k.rounded() ? "\(sign)$\(Int(k))K" : "\(sign)$\(String(format: "%.1f", k))K"
        }
        return "\(sign)$\(Int(value.rounded()))"
    }

    public static func symbolPrefix(for code: String) -> String {
        switch code.uppercased() {
        case "CAD": return "CA$"
        case "USD": return "US$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        default: return code.uppercased() + " "
        }
    }

    public var description: String { formatted() }
}

public extension Decimal {
    var moneyString: String { Money(self).formatted(showsCode: false) }
}
