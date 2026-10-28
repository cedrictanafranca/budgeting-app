import SwiftUI
import BudgetCore
#if os(iOS)
import UIKit
#endif

/// Thin wrapper so call sites stay platform-neutral. No-ops off iOS.
@MainActor
enum Haptics {
    static func impact() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func error() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}

/// SwiftUI exports its own `Transaction`; use this alias for the domain type throughout BudgetUI.
typealias BudgetTransaction = BudgetCore.Transaction
