//
//  Connection.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 18/05/26.
//

import SwiftData
import Foundation

/// Represents a persistent relationship between the current user and a friend.
///
/// A `Connection` ties together the `User` profile of the friend, a `MetaManager` to track the relationship health,
/// and a `FeedManager` to store shared moments. It calculates crucial states, such as whether a friendship has fallen into the "vacuum" state.
@Model
class Connection: Hashable {
    private(set) var id: UUID = UUID()
    
    /// The profile of the friend associated with this connection.
    private(set) var friend: User
    
    var metaManager: MetaManager
    var feedManager: FeedManager
    
    var firstConnection: Date
    var lastMet: Date?
    
    /// The total duration since the connection was initially established.
    var timeConnected: TimeInterval {
        Date.now.timeIntervalSince(firstConnection)
    }
    
    /// The duration since the two users last registered a physical meeting.
    var timeSinceLastMet: TimeInterval {
        Date.now.timeIntervalSince(lastMet ?? Date.now)
    }

    /// Minimum interval between scored meetings with the same friend.
    ///
    /// A 24h cooldown stops a single day of repeated encounters from rocketing the friendship to its
    /// maximum level: meetings registered before it elapses still confirm visually but do not add score.
    static let meetingCooldown: TimeInterval = 24 * 60 * 60

    /// Whether enough time has passed since the last scored meeting to register a new scoring meeting.
    var canRegisterMeeting: Bool {
        guard let lastMet else { return true }
        return Date.now.timeIntervalSince(lastMet) >= Connection.meetingCooldown
    }
    
    var recordNotMeet: TimeInterval? {
        guard let lastMet = lastMet else { return nil }
        return Date.now.timeIntervalSince(lastMet)
    }
    
    var recordTimeNotMeeting: TimeInterval?

    /// A boolean indicating if the connection has decayed into the vacuum state.
    /// Returns `true` when the score reaches zero — caused by consecutive missed meeting periods.
    var inVacuo: Bool {
        return metaManager.score <= 0
    }

    init(friend: User, lastMet: Date? = nil, score: Double = 10.0) {
        self.friend = friend
        self.metaManager = MetaManager(score: score)
        self.feedManager = FeedManager()
        self.firstConnection = Date.now
        self.lastMet = lastMet
    }
}
