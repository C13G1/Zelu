//
//  Grups.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 12/06/26.
//
import Foundation
import SwiftData

@Model
class Grups {
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
    
    init(name: String, image: Data,connections: [Connection]) {
        self.name = name
        self.image = image
        self.connections = connections
    }
}

