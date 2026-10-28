import Foundation
import CheckKit

// Register every suite here. Each suite lives in its own file as `func xxxChecks()`.
moneyChecks()
budgetCalculatorChecks()
categorizationChecks()
duplicateChecks()
recurringChecks()
csvChecks()
defaultDataChecks()
// TODO(store-agent): storeChecks()

CheckRunner.shared.finish()
