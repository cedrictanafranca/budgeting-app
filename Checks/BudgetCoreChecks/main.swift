import Foundation
import CheckKit

// Register every suite here. Each suite lives in its own file as `func xxxChecks()`.
moneyChecks()
// TODO(core-agent): budgetCalculatorChecks(), categorizationChecks(), duplicateChecks(), csvChecks(), recurringChecks(), storeChecks()

CheckRunner.shared.finish()
