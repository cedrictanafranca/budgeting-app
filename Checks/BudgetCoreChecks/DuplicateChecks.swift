import Foundation
import CheckKit
import BudgetCore

func duplicateChecks() {
    typealias F = CoreFixtures
    let detector = DuplicateDetector()

    suite("DuplicateDetector") {
        let original = Transaction(amount: Money(6.45), merchant: "Starbucks #2231", date: F.date(2026, 10, 28, 9, 0))

        check("same purchase 2 minutes apart is a duplicate") {
            let candidate = Transaction(amount: Money(6.45), merchant: "STARBUCKS", date: F.date(2026, 10, 28, 9, 2))
            expectEqual(detector.existingDuplicate(of: candidate, in: [original])?.id, original.id)
        }
        check("same purchase 30 minutes apart is not a duplicate") {
            let candidate = Transaction(amount: Money(6.45), merchant: "Starbucks", date: F.date(2026, 10, 28, 9, 30))
            expect(detector.existingDuplicate(of: candidate, in: [original]) == nil)
        }
        check("different amount is not a duplicate") {
            let candidate = Transaction(amount: Money(7.45), merchant: "Starbucks", date: F.date(2026, 10, 28, 9, 1))
            expect(detector.existingDuplicate(of: candidate, in: [original]) == nil)
        }
        check("different merchant is not a duplicate") {
            let candidate = Transaction(amount: Money(6.45), merchant: "Tim Hortons", date: F.date(2026, 10, 28, 9, 1))
            expect(detector.existingDuplicate(of: candidate, in: [original]) == nil)
        }
        check("fingerprint match wins even outside the window") {
            let date = F.date(2026, 10, 28, 9, 0)
            let fp = DuplicateDetector.fingerprint(merchant: "Starbucks", amount: Money(6.45), date: date)
            var stored = Transaction(amount: Money(6.45), merchant: "Starbucks", date: date, source: .applePay)
            stored.externalFingerprint = fp
            var candidate = Transaction(amount: Money(6.45), merchant: "Starbucks", date: date.addingTimeInterval(3 * 3600), source: .applePay)
            candidate.externalFingerprint = fp
            expectEqual(detector.existingDuplicate(of: candidate, in: [stored])?.id, stored.id)
        }
        check("a transaction is never a duplicate of itself") {
            expect(detector.existingDuplicate(of: original, in: [original]) == nil)
            var stored = original
            stored.externalFingerprint = "fp"
            expect(detector.existingDuplicate(of: stored, in: [stored]) == nil)
        }
        check("income with the same amount is not a purchase duplicate") {
            let refund = Transaction(kind: .income, amount: Money(6.45), merchant: "Starbucks", date: F.date(2026, 10, 28, 9, 1))
            expect(detector.existingDuplicate(of: refund, in: [original]) == nil)
        }
        check("picks the closest match") {
            let near = Transaction(amount: Money(6.45), merchant: "Starbucks", date: F.date(2026, 10, 28, 9, 4))
            let far = Transaction(amount: Money(6.45), merchant: "Starbucks", date: F.date(2026, 10, 28, 9, 9))
            let candidate = Transaction(amount: Money(6.45), merchant: "Starbucks", date: F.date(2026, 10, 28, 9, 5))
            expectEqual(detector.existingDuplicate(of: candidate, in: [far, near])?.id, near.id)
        }
        check("fingerprint is stable and tolerant of merchant noise") {
            let date = F.date(2026, 10, 28, 9, 1)
            expectEqual(
                DuplicateDetector.fingerprint(merchant: "SQ *Blue Bottle #12", amount: Money(5), date: date),
                DuplicateDetector.fingerprint(merchant: "blue bottle", amount: Money(5.00), date: date.addingTimeInterval(60))
            )
            expect(DuplicateDetector.fingerprint(merchant: "a", amount: Money(5), date: date) != DuplicateDetector.fingerprint(merchant: "a", amount: Money(5), date: date.addingTimeInterval(600)))
        }
    }
}
