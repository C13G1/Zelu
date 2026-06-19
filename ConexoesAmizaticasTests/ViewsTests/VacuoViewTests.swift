//
//  VacuoViewTests.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 28/05/26.
//

import Testing
import SwiftUI
import SwiftData
@testable import ConexoesAmizaticas

@MainActor
struct VacuoViewLogicTests {

    private func vacuumConnections(_ all: [Connection]) -> [Connection] {
        all.filter { $0.inVacuo }
    }

    @Test("Filtra apenas connections em vacuum")
    func filtersOnlyVacuumConnections() {
        let active = Connection(friend: User(name: "Active", profilePicture: Data()), score: 30)
        let inVacuum = Connection(friend: User(name: "Vacuum", profilePicture: Data()), score: 0)

        let result = vacuumConnections([active, inVacuum])
        #expect(result.count == 1)
        #expect(result.first?.friend?.getName() == "Vacuum")
    }

    @Test("Retorna vazio quando nenhuma connection está em vacuum")
    func emptyWhenAllActive() {
        let c1 = Connection(friend: User(name: "A", profilePicture: Data()), score: 50)
        let c2 = Connection(friend: User(name: "B", profilePicture: Data()), score: 20)
        #expect(vacuumConnections([c1, c2]).isEmpty)
    }

    @Test("resgatarContato atualiza lastMet e adiciona 5 ao score")
    func rescueResetsLastMetAndBoostsScore() {
        let connection = Connection(friend: User(name: "Resgate", profilePicture: Data()), score: 0)
        #expect(connection.inVacuo == true)

        connection.lastMet = Date.now
        connection.metaManager?.addOrSubtractScore(5)

        #expect(connection.lastMet != nil)
        #expect(connection.metaManager?.score == 5)
        #expect(connection.inVacuo == false)
    }
}
