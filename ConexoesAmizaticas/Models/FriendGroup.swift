//
//  FriendsGroup.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 12/06/26.
//
import Foundation
import SwiftData

/// A named collection of `Connection`s, with its own photo, used to group friends together.
@Model
class FriendGroup {
    var id: UUID
    var name: String
    var image: Data
    var connections: [Connection]

    /// The most common `RelationshipState` among the group's connections, used to color the group.
    /// Falls back to `.afastados` when the group is empty.
    var averageConnectionStrength: RelationshipState {
        guard !connections.isEmpty else { return .afastados }
        
        let allStates = RelationshipState.allCases
        var sum = [RelationshipState: Int]()
        
        for c in connections {
            let state = c.metaManager.currentRelationshipState
            sum[state, default: 0] += 1
        }
        
        return sum.max(by: { $0.value < $1.value })?.key ?? .afastados
    }
    
    init(name: String, image: Data,connections: [Connection]) {
        self.name = name
        self.image = image
        self.connections = connections
        self.id = UUID()
    }
}

