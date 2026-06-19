//
//  FriendsProfileViewTests.swift
//  ConexoesAmizaticas
//
//  Created by Thomas Pinheiro Grandin on 28/05/26.
//

import Testing
import SwiftUI
import SwiftData
@testable import ConexoesAmizaticas


@MainActor
struct FriendsProfileViewLogicTests {

    private func lastMeetDaysText(lastMet: Date?) -> String {
        guard let lastMet = lastMet else { return "nunca" }
        let days = Calendar.current.dateComponents([.day], from: lastMet, to: .now).day ?? 0
        if days == 0 { return "hoje" }
        return "há \(days) dias"
    }

    @Test("Sem encontro retorna 'nunca'")
    func neverWhenNil() {
        #expect(lastMeetDaysText(lastMet: nil) == "nunca")
    }

    @Test("Mesmo dia retorna 'hoje'")
    func todayWhenMetNow() {
        #expect(lastMeetDaysText(lastMet: .now) == "hoje")
    }

    @Test("Vários dias atrás retorna 'há N dias'")
    func severalDaysAgo() {
        let past = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        let text = lastMeetDaysText(lastMet: past)
        #expect(text == "há 10 dias" || text == "há 9 dias")
    }

    private func ownUser(allUsers: [User], connections: [Connection]) -> User? {
        let friendIDs = Set(connections.compactMap { $0.friend?.id })
        return allUsers.first { !friendIDs.contains($0.id) }
    }

    @Test("ownUser identifica usuário que NÃO é amigo de nenhuma connection")
    func ownUserExcludesFriends() {
        let me = User(name: "Eu", profilePicture: Data(), id: UUID())
        let friend = User(name: "Amigo", profilePicture: Data(), id: UUID())
        let connection = Connection(friend: friend)

        let result = ownUser(allUsers: [friend, me], connections: [connection])
        #expect(result?.id == me.id)
    }

    @Test("ownUser retorna nil se todos os usuários estão em conexões")
    func ownUserNilWhenAllAreFriends() {
        let friend = User(name: "F", profilePicture: Data(), id: UUID())
        let connection = Connection(friend: friend)
        #expect(ownUser(allUsers: [friend], connections: [connection]) == nil)
    }
}
