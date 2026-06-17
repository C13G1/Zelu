//
//  FriendsGroup.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 12/06/26.
//
import Foundation
import SwiftData
import UIKit

@Model
class FriendsGroup {
    var id: UUID
    var name: String
    var image: Data
    var connections: [Connection]
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
    
    init(name: String = "Default Name", image: Data = UIImage(named: "defaultPicture")!.jpegData(compressionQuality: 0.99)!,connections: [Connection] = []) {
        self.name = name
        self.image = image
        self.connections = connections
        self.id = UUID()
    }
}

