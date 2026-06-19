//
//  VacuoViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 24/05/26.
//

import Foundation
import SwiftUI
import SwiftData
import Aptabase

/// Drives the "vacuum" recovery screen where deeply decayed connections live.
///
/// `VacuoViewModel` filters the global connections list to those that fell below the score threshold,
/// owns the overlay/modal state and performs the rescue operation (refresh `lastMet`, bump score, save).
@Observable
class VacuoViewModel {
    /// Mirror of the SwiftData query result. Update from the view whenever connections change.
    var allConnections: [Connection] = []

    var showTutorial: Bool = false
    var tutorialStep: Int = 0
    var focusedConnection: Connection?

    /// Subset of the connections that decayed past the vacuum threshold.
    var vacuumConnections: [Connection] {
        allConnections.filter { $0.inVacuo }
    }

    /// Restores the focused connection from the vacuum state and notifies dependent views.
    /// - Parameter modelContext: The SwiftData context used to commit the rescue.
    func rescueFocusedConnection(modelContext: ModelContext) {
        guard let connection = focusedConnection else { return }
        connection.lastMet = Date.now
        connection.metaManager?.addOrSubtractScore(5)
        Aptabase.shared.trackEvent("friend_rescued")
        try? modelContext.save()
        NotificationManager.scheduleMetaReminder(for: connection)
        NotificationCenter.default.post(name: .meetingConfirmed, object: nil)
        focusedConnection = nil
    }
}
