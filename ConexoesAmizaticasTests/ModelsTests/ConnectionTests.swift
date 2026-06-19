//
//  ConnectionTests.swift
//  ConexoesAmizaticas
//
//  Created by Jonas Fernando Nascimento Melo on 28/05/26.
//


import Testing
import Foundation
@testable import ConexoesAmizaticas

struct ConnectionTests {

    private func makeFriend(name: String = "Amigo") -> User {
        User(name: name, profilePicture: Data(), id: UUID())
    }

    @Test("Init guarda friend e cria managers")
    func initStoresFriendAndManagers() {
        let friend = makeFriend(name: "Lucas")
        let connection = Connection(friend: friend)

        #expect(connection.friend?.getName() == "Lucas")
        #expect(connection.metaManager?.score == 10.0)
        #expect(connection.feedManager?.posts?.isEmpty ?? true)
        #expect(connection.lastMet == nil)
    }

    @Test("Init com score customizado propaga ao MetaManager")
    func initPropagatesScore() {
        let connection = Connection(friend: makeFriend(), score: 45.0)
        #expect(connection.metaManager?.score == 45.0)
        #expect(connection.metaManager?.currentRelationshipState == .proximos)
    }

    @Test("firstConnection é definido próximo ao instante atual")
    func firstConnectionIsRecent() {
        let before = Date.now
        let connection = Connection(friend: makeFriend())
        let after = Date.now

        #expect(connection.firstConnection >= before)
        #expect(connection.firstConnection <= after)
    }

    @Test("timeConnected retorna valor não-negativo")
    func timeConnectedIsNonNegative() {
        let connection = Connection(friend: makeFriend())
        #expect(connection.timeConnected >= 0)
    }

    @Test("timeSinceLastMet retorna ~0 quando lastMet é nil")
    func timeSinceLastMetIsZeroWhenNil() {
        let connection = Connection(friend: makeFriend())
        #expect(abs(connection.timeSinceLastMet) < 1.0)
    }

    @Test("timeSinceLastMet calcula intervalo a partir de lastMet")
    func timeSinceLastMetCalculatesInterval() {
        let pastDate = Date.now.addingTimeInterval(-3600)
        let connection = Connection(friend: makeFriend(), lastMet: pastDate)
        #expect(connection.timeSinceLastMet >= 3600)
        #expect(connection.timeSinceLastMet < 3700)
    }

    @Test("recordNotMeet é nil quando lastMet é nil")
    func recordNotMeetNilWhenNoLastMet() {
        let connection = Connection(friend: makeFriend())
        #expect(connection.recordNotMeet == nil)
    }

    @Test("recordNotMeet retorna intervalo correto")
    func recordNotMeetReturnsInterval() {
        let pastDate = Date.now.addingTimeInterval(-7200)
        let connection = Connection(friend: makeFriend(), lastMet: pastDate)
        #expect(connection.recordNotMeet != nil)
        #expect(connection.recordNotMeet! >= 7200)
    }

    @Test("inVacuo é falso quando score > 0")
    func inVacuoFalseWhenScorePositive() {
        let connection = Connection(friend: makeFriend(), score: 10.0)
        #expect(connection.inVacuo == false)
    }

    @Test("inVacuo é true quando score zera")
    func inVacuoTrueWhenScoreIsZero() {
        let connection = Connection(friend: makeFriend(), score: 0.0)
        #expect(connection.inVacuo == true)
    }

    @Test("inVacuo torna-se true após decay completo")
    func inVacuoAfterFullDecay() {
        let connection = Connection(friend: makeFriend(), score: 5.0)
        connection.metaManager?.setMeta(.semanal)
        let oldDate = Calendar.current.date(byAdding: .day, value: -365, to: .now)
        connection.metaManager?.applyDecayIfNeeded(lastMet: oldDate)
        #expect(connection.inVacuo == true)
    }

    @Test("Cada connection tem um id único")
    func connectionsHaveUniqueIds() {
        let c1 = Connection(friend: makeFriend())
        let c2 = Connection(friend: makeFriend())
        #expect(c1.id != c2.id)
    }
}
