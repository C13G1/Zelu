//
//  UserProfileViewTests.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 28/05/26.
//

import Testing
import SwiftUI
import SwiftData
@testable import ConexoesAmizaticas

@MainActor
struct UserProfileViewLogicTests {

    private func friendsByState(_ connections: [Connection]) -> [(state: RelationshipState, count: Int)] {
        let orderedStates: [RelationshipState] = [
            .afastados, .proximos, .distantes, .estaveis, .inseparaveis
        ]
        let grouped = Dictionary(grouping: connections) { $0.metaManager?.currentRelationshipState ?? .afastados }
        return orderedStates.compactMap { state in
            let count = grouped[state]?.count ?? 0
            guard count > 0 else { return nil }
            return (state: state, count: count)
        }
    }

    @Test("friendsByState retorna vazio quando não há conexões")
    func emptyConnections() {
        #expect(friendsByState([]).isEmpty)
    }

    @Test("Conta corretamente conexões por estado")
    func groupsByState() {
        let c1 = Connection(friend: User(name: "A", profilePicture: Data()), score: 0)   // afastados
        let c2 = Connection(friend: User(name: "B", profilePicture: Data()), score: 0)   // afastados
        let c3 = Connection(friend: User(name: "C", profilePicture: Data()), score: 50)  // inseparaveis

        let result = friendsByState([c1, c2, c3])
        let dict = Dictionary(uniqueKeysWithValues: result.map { ($0.state, $0.count) })

        #expect(dict[.afastados] == 2)
        #expect(dict[.inseparaveis] == 1)
        #expect(dict[.estaveis] == nil)
    }

    @Test("Omite estados sem conexões")
    func skipsEmptyStates() {
        let c = Connection(friend: User(name: "X", profilePicture: Data()), score: 50)
        let result = friendsByState([c])
        #expect(result.count == 1)
        #expect(result.first?.state == .inseparaveis)
    }

    private func lastMeetingText(_ connections: [Connection]) -> String {
        let mostRecent = connections.compactMap { $0.lastMet }.max()
        guard let mostRecent else { return "NUNCA" }
        let days = Calendar.current.dateComponents([.day], from: mostRecent, to: .now).day ?? 0
        if days == 0 { return "HOJE" }
        if days == 1 { return "HÁ 1 DIA" }
        return "HÁ \(days) DIAS"
    }

    @Test("Sem encontros retorna 'NUNCA'")
    func neverWhenNoMeetings() {
        let c = Connection(friend: User(name: "A", profilePicture: Data()), lastMet: nil)
        #expect(lastMeetingText([c]) == "NUNCA")
    }

    @Test("Encontro hoje retorna 'HOJE'")
    func todayWhenMetToday() {
        let c = Connection(friend: User(name: "A", profilePicture: Data()), lastMet: .now)
        #expect(lastMeetingText([c]) == "HOJE")
    }

    @Test("Encontro há 1 dia retorna 'HÁ 1 DIA' (singular)")
    func singularYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)
        let c = Connection(friend: User(name: "A", profilePicture: Data()), lastMet: yesterday)
        #expect(lastMeetingText([c]) == "HÁ 1 DIA")
    }

    @Test("Encontro há N dias retorna no plural")
    func pluralDays() {
        let past = Calendar.current.date(byAdding: .day, value: -5, to: .now)
        let c = Connection(friend: User(name: "A", profilePicture: Data()), lastMet: past)
        let text = lastMeetingText([c])
        #expect(text == "HÁ 5 DIAS" || text == "HÁ 4 DIAS") // tolerância de arredondamento
    }

    @Test("Usa a data mais recente entre múltiplas conexões")
    func usesMostRecentDate() {
        let old = Calendar.current.date(byAdding: .day, value: -30, to: .now)
        let c1 = Connection(friend: User(name: "A", profilePicture: Data()), lastMet: old)
        let c2 = Connection(friend: User(name: "B", profilePicture: Data()), lastMet: .now)
        #expect(lastMeetingText([c1, c2]) == "HOJE")
    }
}
