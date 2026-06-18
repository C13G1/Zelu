//
//  FriendProfileViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 20/05/26.
//

import Foundation
import SwiftUI
import SwiftData

/// A presentation layer responsible for formatting the raw database connection data into human-readable metrics.
///
/// It acts as a bridge between the complex `Connection` model and the `FriendsProfileView`, isolating UI
/// components from database calculations like calendar math, goal tracking, and dynamic styling based on relationship state.
@Observable
class FriendProfileViewModel {
    private(set) var connection: Connection
    
    init(connection: Connection) {
        self.connection = connection
        self.setRecordTimeNotMeeting()
    }
    
    /// Overwrites the current interaction goal established for this relationship.
    func defineMeta(meta: Meta){
        connection.metaManager.setMeta(meta)
    }
    
    func getMeta() -> Meta {
        return connection.metaManager.meta
    }
    
    func getFriendImage() -> UIImage? {
        return UIImage(data: connection.friend.getProfileImageData())
    }
    
    func getFriendName() -> String {
        return connection.friend.getName()
    }
    
    /// Calculates the total lifespan of the metaManager in exact days.
    func getConnectionTime() -> Int {
        daysElapsed(since: connection.timeConnected)
    }
    
    /// Computes the elapsed days since the user and the friend last recorded a physical meeting.
    func getTimeSinceLastMet() -> Int {
        daysElapsed(since: connection.timeSinceLastMet)
    }
    
    func getLastMeet() -> Date? {
        return connection.lastMet
    }
    
    /// Validates if the current absence streak breaks the historical record for this specific metaManager.
    func setRecordTimeNotMeeting() {
        if connection.timeSinceLastMet > connection.recordTimeNotMeeting ?? 0 {
            connection.recordTimeNotMeeting = connection.timeSinceLastMet
        }
    }
    
    func getRecordTimeNotMeeting() -> Int {
        setRecordTimeNotMeeting()
        return daysElapsed(since: connection.recordTimeNotMeeting ?? 0)
    }
    
    /// Derives the visual UI theme color based on the current health score of the relationship.
    func getProfileColor() -> Color {
        return Color(connection.metaManager.currentRelationshipState.color)
    }
    
    /// Computes the remaining time before the user fails their set relationship goal (`Meta`).
    /// - Returns: A positive integer representing remaining days, or a negative integer if the goal is overdue.
    func getTimeUntilMeet() -> Int {
        connection.metaManager.meta.days - getTimeSinceLastMet()
    }
    
    /// Permanently removes the connection, its score/feed managers and the underlying friend from SwiftData.
    ///
    /// Also cancels the matching meta reminder so no orphaned notification fires after deletion.
    /// - Parameter modelContext: The SwiftData context that should commit the cascading delete.
    func deleteConnection(modelContext: ModelContext) {
        NotificationManager.cancelMetaReminder(for: connection)
        modelContext.delete(connection.metaManager)
        modelContext.delete(connection.feedManager)
        modelContext.delete(connection.friend)
        modelContext.delete(connection)
        try? modelContext.save()
    }

    /// Converts a positive interval representing a duration ending at the present moment into elapsed whole days.
    /// - Parameter interval: A `TimeInterval` such as `timeConnected` or `timeSinceLastMet`.
    /// - Returns: The number of whole days the interval covers. Returns `0` when the interval is too short to span a full day.
    private func daysElapsed(since interval: TimeInterval) -> Int {
        let referenceDate = Date(timeIntervalSinceNow: interval)
        let days = Calendar.current.dateComponents([.day], from: referenceDate, to: Date()).day ?? 0
        return -days
    }
}
