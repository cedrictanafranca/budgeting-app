import Foundation
import CheckKit
import BudgetCore

func moneyChecks() {
    suite("Money") {
        check("formatting matches Luna style") {
            expectEqual(Money(0).formatted(), "CA$0.00")
            expectEqual(Money(1234.5).formatted(), "CA$1,234.50")
            expectEqual(Money(-31.36).formatted(showsCode: false), "-$31.36")
            expectEqual(Money(1100).compact(), "$1.1K")
            expectEqual(Money(750).compact(), "$750")
        }
        check("parsing user and shortcut input") {
            expectEqual(Money(string: "12.50")?.amount, Decimal(string: "12.50"))
            expectEqual(Money(string: "CA$1,234.00")?.amount, 1234)
            expect(Money(string: "abc") == nil)
            expectEqual(Money(double: 0.1 + 0.2).amount, Decimal(string: "0.30"))
        }
        check("arithmetic is decimal safe") {
            expectEqual(Money.sum([Money(0.1), Money(0.2)]).amount, Decimal(string: "0.3"))
        }
    }
}
