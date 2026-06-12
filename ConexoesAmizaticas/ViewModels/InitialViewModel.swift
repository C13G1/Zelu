//
//  InitialViewModel.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 20/05/26.
//

import SwiftUI
import Foundation
import SwiftData

/// The central source of truth for the application's root state.
///
/// `InitialViewModel` manages the active user profile and oversees the comprehensive list of their
/// social connections. It serves as the primary data provider for the root navigational structures
/// (like `InitialView` and `TabBar`) and handles initial data fetching from SwiftData on launch.
@Observable
class InitialViewModel {
    private(set) var modelContext           : ModelContext!
    private(set) var connectionsWithFriends : [Connection] = []
    private(set) var friendsGroups                 : [FriendsGroup] = []
    var profile                             : User = User(name: "")

    /// Pulls the primary user and all active connections from local persistence.
    func fetchData() {
        do {
            let userDescriptor        = FetchDescriptor<User>()
            let connectionsDescriptor = FetchDescriptor<Connection>()
            let friendsGroupsDescriptor = FetchDescriptor<FriendsGroup>()
            
            var users                 = try modelContext.fetch(userDescriptor)
            let connections           = try modelContext.fetch(connectionsDescriptor)
            let friendsGroups                = try modelContext.fetch(friendsGroupsDescriptor)
            guard users.count > 0 else { return }
            profile                   = users.removeFirst()
            connectionsWithFriends    = connections
            self.friendsGroups        = friendsGroups
        } catch {
            print("Fetch failed")
        }
    }
    
    /// Extracts a flat array of `User` profiles from the complex `Connection` models.
    func getFriends() -> [User] {
        var friends: [User] = []
        
        for connection in connectionsWithFriends {
            friends.append(connection.friend)
        }
        return friends
    }
    
    /// Extracts a flat array of `FriendsGroup` profiles from the complex `Connection` models.
    func getFriendsGroups() -> [FriendsGroup] {
        var friendsGroups: [FriendsGroup] = []
        
        for friendsGroup in self.friendsGroups {
            friendsGroups.append(friendsGroup)
        }
        return friendsGroups
    }
    
    func convertDataToImage(data: Data) -> UIImage? {
        return UIImage(data: data)
    }
    
    func setModelContext(modelContext: ModelContext){
        self.modelContext = modelContext
    }
    
    /// Retrieves a specific persistent connection based on the friend's unique user identifier.
    func getConnectionByFriend(friend: User) -> Connection? {
        for c in connectionsWithFriends {
            if c.friend.id == friend.id {
                return c
            }
        }
        return nil
    }

    /// Applies score decay to every saved connection and reschedules every pending meta reminder.
    ///
    /// Called once when the root view appears, this method ensures connections that the user missed
    /// while the app was closed get their decay applied and their reminders refreshed in one pass.
    /// - Parameter connections: The connections to evaluate, typically the SwiftData query result.
    func bootstrap(connections: [Connection]) {
        for connection in connections {
            connection.metaManager.applyDecayIfNeeded(lastMet: connection.lastMet)
        }
        try? modelContext?.save()
        NotificationManager.rescheduleAll(connections: connections)
    }
}
